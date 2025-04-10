--[=[
	Base of a template retrieval system. Templates can be retrieved from Roblox and then retrieved by name. If a folder is used
	all of their children are also included as templates, which allows for flexible organization by artists.

	Additionally, you can provide template overrides as the last added template will always be used.

	```lua
	-- shared/CarTemplates.lua

	return TemplateProvider.new(script.Name, script) -- Load locally
	```

	:::tip
	If the TemplateProvider is initialized on the server, the the templates will be hidden from the client until the
	client requests them.

	This prevents large amounts of templates from being rendered to the client, taking up memory on the client. This especially
	affects meshes, but can also affect sounds and other similar templates.
	:::

	```lua
	-- Server
	local serviceBag = ServiceBag.new()
	local templates = serviceBag:GetService(require("CarTemplates"))
	serviceBag:Init()
	serviceBag:Start()
	```

	```lua
	-- Client
	local serviceBag = ServiceBag.new()
	local templates = serviceBag:GetService(require("CarTemplates"))
	serviceBag:Init()
	serviceBag:Start()

	templates:PromiseCloneTemplate("CopCar"):Then(function(crate)
		print("Got crate!")
	end)
	```

	@class TemplateProvider
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Brio = require("Brio")
local DuckTypeUtils = require("DuckTypeUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableCountingMap = require("ObservableCountingMap")
local ObservableMapList = require("ObservableMapList")
local Promise = require("Promise")
local PromiseMaidUtils = require("PromiseMaidUtils")
local Remoting = require("Remoting")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local String = require("String")
local TemplateReplicationModes = require("TemplateReplicationModes")
local TemplateReplicationModesUtils = require("TemplateReplicationModesUtils")
local _ServiceBag = require("ServiceBag")

local TOMBSTONE_ID_ATTRIBUTE = "UnreplicatedTemplateId"
local TOMBSTONE_NAME_POSTFIX_UNLOADED = "_Unloaded"
local TOMBSTONE_NAME_POSTFIX_LOADED = "_Loaded"

local TemplateProvider = {}
TemplateProvider.ClassName = "TemplateProvider"
TemplateProvider.ServiceName = "TemplateProvider"
TemplateProvider.__index = TemplateProvider

--[=[
	@type TemplateDeclaration Instance | Observable<Brio<Instance>> | table
	@within TemplateProvider
]=]
export type TemplateDeclaration = Instance | Observable.Observable<Brio.Brio<Instance>> | { TemplateDeclaration }

export type TemplateProvider = typeof(setmetatable(
	{} :: {
		_serviceBag: _ServiceBag.ServiceBag,
		_initialTemplates: TemplateDeclaration,
		_maid: Maid.Maid,
		_templateMapList: any, -- ObservableMapList.ObservableMapList<Instance>,
		_unreplicatedTemplateMapList: any, -- ObservableMapList.ObservableMapList<Instance>,
		_containerRootCountingMap: ObservableCountingMap.ObservableCountingMap<Instance>,
		_remoting: Remoting.Remoting,
		_tombstoneLookup: { [string]: Instance },
		_pendingTemplatePromises: { [string]: Promise.Promise<Instance> },
		_pendingTombstoneRequests: { [string]: Promise.Promise<Instance> },
		_replicationMode: TemplateReplicationModes.TemplateReplicationMode,
	},
	{} :: typeof({ __index = TemplateProvider })
))

--[=[
	Constructs a new [TemplateProvider].

	@param providerName string
	@param initialTemplates TemplateDeclaration
]=]
function TemplateProvider.new(providerName: string, initialTemplates: TemplateDeclaration): TemplateProvider
	assert(type(providerName) == "string", "Bad providerName")
	local self = setmetatable({}, TemplateProvider)

	self.ServiceName = assert(providerName, "No providerName")
	self._initialTemplates = initialTemplates

	if not (self:_isValidTemplateDeclaration(self._initialTemplates) or self._initialTemplates == nil) then
		error(
			string.format(
				"[TemplateProvider.%s] - Bad initialTemplates of type %s",
				self.ServiceName,
				typeof(initialTemplates)
			)
		)
	end

	return self
end

--[=[
	Returns if the value is a template provider

	@param value any
	@return boolean
]=]

function TemplateProvider.isTemplateProvider(value: any): boolean
	return DuckTypeUtils.isImplementation(TemplateProvider, value)
end

--[=[
	Initializes the container provider. Should be done via [ServiceBag].

	@param serviceBag ServiceBag
]=]
function TemplateProvider.Init(self: TemplateProvider, serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._replicationMode = TemplateReplicationModesUtils.inferReplicationMode()

	-- There can be multiple templates for a given name
	self._templateMapList = self._maid:Add(ObservableMapList.new())
	self._unreplicatedTemplateMapList = self._maid:Add(ObservableMapList.new())

	self._containerRootCountingMap = self._maid:Add(ObservableCountingMap.new())
	self._pendingTemplatePromises = {} -- [templateName] = Promise

	self:_setupTemplateCache()
end

function TemplateProvider._setupTemplateCache(self: TemplateProvider)
	if self._replicationMode == TemplateReplicationModes.SERVER then
		self._tombstoneLookup = {}
		self._remoting = self._maid:Add(Remoting.Server.new(ReplicatedStorage, self.ServiceName .. "TemplateProvider"))

		-- TODO: Maybe de-duplicate and use a centralized service
		self._maid:GiveTask(self._remoting.ReplicateTemplate:Bind(function(player, tombstoneId)
			assert(type(tombstoneId) == "string", "Bad tombstoneId")
			assert(self._tombstoneLookup[tombstoneId], "Not a valid tombstone")

			-- Stuff doesn't replicate in the PlayerGui
			local playerGui = player:FindFirstChildWhichIsA("PlayerGui")
			if not playerGui then
				return Promise.rejected("No playerGui")
			end

			-- Just group stuff to simplify things
			local replicationParent = playerGui:FindFirstChild("TemplateProviderReplication")
			if not replicationParent then
				replicationParent = Instance.new("Folder")
				replicationParent.Name = "TemplateProviderReplication"
				replicationParent.Archivable = false
				replicationParent.Parent = playerGui
			end

			local copy = self._tombstoneLookup[tombstoneId]:Clone()
			copy.Parent = playerGui

			task.delay(0.1, function()
				copy:Remove()
			end)

			return copy
		end))
	elseif self._replicationMode == TemplateReplicationModes.CLIENT then
		self._pendingTombstoneRequests = {}

		self._remoting = self._maid:Add(Remoting.Client.new(ReplicatedStorage, self.ServiceName .. "TemplateProvider"))
	end

	if self._initialTemplates then
		self._maid:GiveTask(self:AddTemplates(self._initialTemplates))
	end

	-- Recursively adds roots, but also de-duplicates them as necessary
	self._maid:GiveTask(self._containerRootCountingMap:ObserveKeysBrio():Subscribe(function(containerBrio)
		if containerBrio:IsDead() then
			return
		end

		local containerMaid, container = containerBrio:ToMaidAndValue()
		self:_handleContainer(containerMaid, container)
	end))
end

function TemplateProvider._handleContainer(self: TemplateProvider, containerMaid: Maid.Maid, container: Instance)
	if
		self._replicationMode == TemplateReplicationModes.SERVER
		and not container:IsA("Camera")
		and not container:FindFirstAncestorWhichIsA("Camera")
	then
		-- Prevent replication to client immediately

		local camera = containerMaid:Add(Instance.new("Camera"))
		camera.Name = "PreventReplication"
		camera.Parent = container

		local function handleChild(child)
			if child == camera then
				return
			end
			if child:GetAttribute(TOMBSTONE_ID_ATTRIBUTE) then
				return
			end

			child.Parent = camera
		end

		containerMaid:GiveTask(container.ChildAdded:Connect(handleChild))

		for _, child in container:GetChildren() do
			handleChild(child)
		end

		self:_replicateTombstones(containerMaid, camera, container)

		return
	end

	containerMaid:GiveTask(RxInstanceUtils.observeChildrenBrio(container):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, child = brio:ToMaidAndValue()
		self:_addInstanceTemplate(maid, child)
	end))
end

function TemplateProvider._replicateTombstones(
	self: TemplateProvider,
	topMaid: Maid.Maid,
	unreplicatedParent,
	replicatedParent
)
	assert(self._replicationMode == TemplateReplicationModes.SERVER, "Only should be invoked on server")

	-- Tombstone each child so the client knows what is replicated
	topMaid:GiveTask(RxInstanceUtils.observeChildrenBrio(unreplicatedParent):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, child = brio:ToMaidAndValue()
		self:_addInstanceTemplate(maid, child)

		local tombstoneId = HttpService:GenerateGUID(false)

		-- Tell the client something exists here
		local tombstone = maid:Add(Instance.new("Folder"))
		tombstone.Name = child.Name .. TOMBSTONE_NAME_POSTFIX_UNLOADED
		tombstone:SetAttribute(TOMBSTONE_ID_ATTRIBUTE, tombstoneId)

		-- Recursively replicate other tombstones
		if self:_shouldAddChildrenAsTemplates(child) then
			self:_replicateTombstones(maid, child, tombstone)
		end

		self._tombstoneLookup[tombstoneId] = child

		maid:GiveTask(function()
			self._tombstoneLookup[tombstoneId] = nil
		end)

		tombstone.Parent = replicatedParent
	end))
end

--[=[
	Observes the given template by name

	@param templateName string
	@return Observable<Instance>
]=]
function TemplateProvider.ObserveTemplate(self: TemplateProvider, templateName: string): Observable.Observable<Instance>
	assert(type(templateName) == "string", "Bad templateName")

	return self._templateMapList:ObserveList(templateName):Pipe({
		Rx.switchMap(function(list)
			if not list then
				return Rx.of(nil)
			end

			return list:ObserveAtIndex(-1)
		end),
	})
end

function TemplateProvider.ObserveTemplateNamesBrio(self: TemplateProvider): Observable.Observable<Brio.Brio<string>>
	return self._templateMapList:ObserveKeysBrio()
end

function TemplateProvider.ObserveUnreplicatedTemplateNamesBrio(
	self: TemplateProvider
): Observable.Observable<Brio.Brio<string>>
	return self._unreplicatedTemplateMapList:ObserveKeysBrio()
end

--[=[
	Returns the raw template

	@param templateName string
	@return Instance?
]=]
function TemplateProvider.GetTemplate(self: TemplateProvider, templateName: string): Instance?
	assert(type(templateName) == "string", "Bad templateName")

	return self._templateMapList:GetItemForKeyAtIndex(templateName, -1)
end

--[=[
	Promises to clone the template as soon as it exists

	@param templateName string
	@return Promise<Instance>
]=]
function TemplateProvider.PromiseCloneTemplate(self: TemplateProvider, templateName: string): Promise.Promise<Instance>
	assert(type(templateName) == "string", "Bad templateName")

	return self:PromiseTemplate(templateName):Then(function(template)
		return self:_cloneTemplate(template)
	end)
end

--[=[
	Promise to resolve the raw template as soon as it exists

	@param templateName string
	@return Promise<Instance>
]=]
function TemplateProvider.PromiseTemplate(self: TemplateProvider, templateName: string): Promise.Promise<Instance>
	assert(type(templateName) == "string", "Bad templateName")

	local foundTemplate = self._templateMapList:GetItemForKeyAtIndex(templateName, -1)
	if foundTemplate then
		return Promise.resolved(foundTemplate)
	end

	if self._pendingTemplatePromises[templateName] then
		return self._pendingTemplatePromises[templateName]
	end

	local promiseTemplate = Promise.new()

	-- Observe thet template
	PromiseMaidUtils.whilePromise(promiseTemplate, function(topMaid)
		topMaid:GiveTask(self:ObserveTemplate(templateName):Subscribe(function(template)
			if template then
				promiseTemplate:Resolve(template)
			end
		end))

		if self._replicationMode == TemplateReplicationModes.SERVER then
			-- There's a chance an external process will stream in our template

			topMaid:GiveTask(task.delay(5, function()
				warn(
					string.format(
						"[TemplateProvider.%s.PromiseTemplate] - Missing template %q",
						self.ServiceName,
						templateName
					)
				)
			end))
		elseif self._replicationMode == TemplateReplicationModes.CLIENT then
			-- Replicate from the unfound area
			topMaid:GiveTask(
				self._unreplicatedTemplateMapList:ObserveAtListIndexBrio(templateName, -1):Subscribe(function(brio)
					if brio:IsDead() then
						return
					end

					local maid, templateTombstone = brio:ToMaidAndValue()

					local originalName = templateTombstone.Name

					maid:GivePromise(self:_promiseReplicateTemplateFromTombstone(templateTombstone))
						:Then(function(template)
							-- Cache the template here which then loads it into the known templates naturally
							templateTombstone.Name = String.removePostfix(originalName, TOMBSTONE_NAME_POSTFIX_UNLOADED)
								.. TOMBSTONE_NAME_POSTFIX_LOADED
							template.Parent = templateTombstone

							promiseTemplate:Resolve(template)
						end)
				end)
			)

			topMaid:GiveTask(task.delay(5, function()
				if self._unreplicatedTemplateMapList:GetListForKey(templateName) then
					warn(
						string.format(
							"[TemplateProvider.%s.PromiseTemplate] - Failed to replicate template %q from server to client",
							self.ServiceName,
							templateName
						)
					)
				else
					warn(
						string.format(
							"[TemplateProvider.%s.PromiseTemplate] - Template %q is not a known template",
							self.ServiceName,
							templateName
						)
					)
				end
			end))
		elseif self._replicationMode == TemplateReplicationModes.SHARED then
			-- There's a chance an external process will stream in our template

			topMaid:GiveTask(task.delay(5, function()
				warn(
					string.format(
						"[TemplateProvider.%s.PromiseTemplate] - Missing template %q",
						self.ServiceName,
						templateName
					)
				)
			end))
		else
			error("Bad replicationMode")
		end
	end)

	self._maid[promiseTemplate] = promiseTemplate
	self._pendingTemplatePromises[templateName] = promiseTemplate

	promiseTemplate:Finally(function()
		self._maid[promiseTemplate] = nil
		self._pendingTemplatePromises[templateName] = nil
	end)

	return promiseTemplate
end

function TemplateProvider._promiseReplicateTemplateFromTombstone(
	self: TemplateProvider,
	templateTombstone: Instance
): Promise.Promise<Instance>
	assert(self._replicationMode == TemplateReplicationModes.CLIENT, "Bad replicationMode")
	assert(typeof(templateTombstone) == "Instance", "Bad templateTombstone")

	local tombstoneId = templateTombstone:GetAttribute(TOMBSTONE_ID_ATTRIBUTE)
	if type(tombstoneId) ~= "string" then
		return Promise.rejected("tombstoneId must be a string")
	end

	if self._pendingTombstoneRequests[tombstoneId] then
		return self._pendingTombstoneRequests[tombstoneId]
	end

	local promiseTemplate = Promise.new()

	PromiseMaidUtils.whilePromise(promiseTemplate, function(topMaid)
		topMaid
			:GivePromise(self._remoting.ReplicateTemplate:PromiseInvokeServer(tombstoneId))
			:Then(function(tempTemplate)
				if not tempTemplate then
					Promise.rejected("Failed to get any template")
					return
				end

				-- This tempTemplate will get destroyed by the server soon to free up server memory
				-- TODO: cache on client
				local copy = tempTemplate:Clone()
				promiseTemplate:Resolve(copy)
			end, function(...)
				promiseTemplate:Reject(...)
			end)
	end)

	self._maid[promiseTemplate] = promiseTemplate
	self._pendingTombstoneRequests[tombstoneId] = promiseTemplate

	promiseTemplate:Finally(function()
		self._maid[promiseTemplate] = nil
		self._pendingTombstoneRequests[tombstoneId] = nil
	end)

	return promiseTemplate
end

--[=[
	Clones the template.

	:::info
	If the template name has a prefix of "Template" then it will remove it on the cloned instance.
	:::

	@param templateName string
	@return Instance?
]=]
function TemplateProvider.CloneTemplate(self: TemplateProvider, templateName: string): Instance?
	assert(type(templateName) == "string", "Bad templateName")

	local template = self._templateMapList:GetItemForKeyAtIndex(templateName, -1)
	if not template then
		local unreplicated = self._unreplicatedTemplateMapList:GetListForKey(templateName)

		if unreplicated then
			error(
				string.format(
					"[TemplateProvider.%s.CloneTemplate] - Template %q is not replicated. Use PromiseCloneTemplate instead",
					self.ServiceName,
					tostring(templateName)
				)
			)
		else
			error(
				string.format(
					"[TemplateProvider.%s.CloneTemplate] - Cannot provide template %q",
					self.ServiceName,
					tostring(templateName)
				)
			)
		end
	end

	return self:_cloneTemplate(template)
end

--[=[
	Adds a new container to the provider for provision of assets. The initial container
	is considered a template. Additionally, we will include any children that are in a folder
	as a potential root

	:::tip
	The last template with a given name added will be considered the canonical template.
	:::

	@param container Template
	@return MaidTask
]=]
function TemplateProvider.AddTemplates(self: TemplateProvider, container: TemplateDeclaration): () -> ()
	assert(self:_isValidTemplateDeclaration(container), "Bad container")

	if typeof(container) == "Instance" then
		-- Always add this instance as we explicitly asked for it to be added as a root. This could be a
		-- module script, or other component.
		return self._containerRootCountingMap:Add(container)
	elseif Observable.isObservable(container) then
		local topMaid = Maid.new()

		self:_addObservableTemplates(topMaid, container)

		self._maid[topMaid] = topMaid
		topMaid:GiveTask(function()
			self._maid[topMaid] = nil
		end)

		return topMaid
	elseif type(container) == "table" then
		local topMaid = Maid.new()

		for _, value in container :: any do
			if typeof(value) == "Instance" then
				-- Always add these as we explicitly ask for this to be a root too.
				topMaid:GiveTask(self._containerRootCountingMap:Add(value))
			elseif Observable.isObservable(value) then
				self:_addObservableTemplates(topMaid, value)
			else
				error(
					string.format(
						"[TemplateProvider.%s] - Bad value of type %q in container table",
						self.ServiceName,
						typeof(value)
					)
				)
			end
		end

		self._maid[topMaid] = topMaid
		topMaid:GiveTask(function()
			self._maid[topMaid] = nil
		end)

		return function()
			self._maid[topMaid] = nil
		end
	else
		error(string.format("[TemplateProvider.%s] - Bad container of type %s", self.ServiceName, typeof(container)))
	end
end

function TemplateProvider._addObservableTemplates(self: TemplateProvider, topMaid: Maid.Maid, observable)
	topMaid:GiveTask(observable:Subscribe(function(result)
		if Brio.isBrio(result) then
			if result:IsDead() then
				return
			end

			local maid, template = result:ToMaidAndValue()
			if typeof(template) == "Instance" then
				self:_addInstanceTemplate(maid, template)
			else
				error("Cannot add non-instance from observable template")
			end
		else
			error("Cannot add non Brio<Instance> from observable")
		end
	end))
end

function TemplateProvider._addInstanceTemplate(self: TemplateProvider, topMaid: Maid.Maid, template: Instance)
	if self:_shouldAddChildrenAsTemplates(template) then
		topMaid:GiveTask(self._containerRootCountingMap:Add(template))
	end

	if template:GetAttribute(TOMBSTONE_ID_ATTRIBUTE) then
		topMaid:GiveTask(self._unreplicatedTemplateMapList:Push(
			RxInstanceUtils.observeProperty(template, "Name"):Pipe({
				Rx.map(function(name)
					if String.endsWith(name, TOMBSTONE_NAME_POSTFIX_UNLOADED) then
						return String.removePostfix(name, TOMBSTONE_NAME_POSTFIX_UNLOADED)
					elseif String.endsWith(name, TOMBSTONE_NAME_POSTFIX_LOADED) then
						return String.removePostfix(name, TOMBSTONE_NAME_POSTFIX_LOADED)
					else
						return name
					end
				end),
				Rx.distinct(),
			}),
			template
		))
	else
		topMaid:GiveTask(self._templateMapList:Push(RxInstanceUtils.observeProperty(template, "Name"), template))
	end
end

--[=[
	Returns whether or not a template is registered at the time

	@param templateName string
	@return boolean
]=]
function TemplateProvider.IsTemplateAvailable(self: TemplateProvider, templateName: string)
	assert(type(templateName) == "string", "Bad templateName")

	return self._templateMapList:GetItemForKeyAtIndex(templateName, -1) ~= nil
end

--[=[
	Returns all current registered items.

	@return { Instance }
]=]
function TemplateProvider.GetTemplateList(self: TemplateProvider): { Instance }
	return self._templateMapList:GetListOfValuesAtListIndex(-1)
end

--[=[
	Gets all current the containers.

	@return { Instance }
]=]
function TemplateProvider.GetContainerList(self: TemplateProvider): { Instance }
	return self._containerRootCountingMap:GetKeyList()
end

function TemplateProvider._cloneTemplate(_self: TemplateProvider, template: Instance): Instance
	local newItem = template:Clone()
	newItem.Name = String.removePostfix(template.Name, "Template")
	return newItem
end

function TemplateProvider._shouldAddChildrenAsTemplates(_self: TemplateProvider, container: Instance): boolean
	return container:IsA("Folder")
end

function TemplateProvider._isValidTemplateDeclaration(_self: TemplateProvider, container: TemplateDeclaration): boolean
	return typeof(container) == "Instance" or Observable.isObservable(container) or type(container) == "table"
end

-- Backwards compatibility
TemplateProvider.IsAvailable = assert(TemplateProvider.IsTemplateAvailable, "Missing method")
TemplateProvider.Get = assert(TemplateProvider.GetTemplate, "Missing method")
TemplateProvider.Clone = assert(TemplateProvider.CloneTemplate, "Missing method")
TemplateProvider.PromiseClone = assert(TemplateProvider.PromiseCloneTemplate, "Missing method")
TemplateProvider.GetAllTemplates = assert(TemplateProvider.GetTemplateList, "Missing method")
TemplateProvider.GetAll = assert(TemplateProvider.GetTemplateList, "Missing method")


--[=[
	Cleans up the provider
]=]
function TemplateProvider.Destroy(self: TemplateProvider)
	self._maid:DoCleaning()
end

return TemplateProvider