--[=[
	Base of a template retrieval system. Templates can be retrieved from Roblox, or from the cloud,
	and then retrieved by name. Folders are ignored, so assets may be organized however you want.

	Templates can repliate to client if desired.

	```lua
	-- shared/Templates.lua

	return TemplateProvider.new(182451181, script) -- Load from Roblox cloud
	```

	```lua
	-- Server
	local serviceBag = ServiceBag.new()
	local templates = serviceBag:GetService(require("Templates"))
	serviceBag:Init()
	serviceBag:Start()
	```

	```lua
	-- Client
	local serviceBag = ServiceBag.new()
	local templates = serviceBag:GetService(require("Templates"))
	serviceBag:Init()
	serviceBag:Start()

	templates:PromiseClone("Crate"):Then(function(crate)
		print("Got crate from the cloud!")
	end)
	```

	@class TemplateProvider
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Maid = require("Maid")
local String = require("String")
local InsertServiceUtils = require("InsertServiceUtils")
local Promise = require("Promise")

local TemplateProvider = {}
TemplateProvider.ClassName = "TemplateProvider"
TemplateProvider.ServiceName = "TemplateProvider"
TemplateProvider.__index = TemplateProvider

--[=[
	Constructs a new [TemplateProvider].
	@param container Instance | table | number -- Value
	@param replicationParent Instance? -- Place to replicate instances to.
]=]
function TemplateProvider.new(container, replicationParent)
	local self = setmetatable({}, TemplateProvider)

	self._replicationParent = replicationParent
	self._containersToInitializeSet = {}
	self._containersToInitializeList = {}

	if typeof(container) == "Instance" or type(container) == "number" then
		self:_registerContainer(container)
	elseif typeof(container) == "table" then
		for _, item in pairs(container) do
			assert(typeof(item) == "Instance" or type(item) == "number", "Bad item in initialization set")

			self:_registerContainer(item)

			-- For easy debugging/iteration loop
			if typeof(item) == "Instance"
				and item:IsDescendantOf(StarterGui)
				and item:IsA("ScreenGui")
				and RunService:IsRunning() then

				item.Enabled = false
			end
		end
	end

	-- Make sure to replicate our parent
	if self._replicationParent then
		self:_registerContainer(self._replicationParent)
	end

	return self
end

function TemplateProvider:_registerContainer(container)
	assert(typeof(container) == "Instance" or type(container) == "number", "Bad container")

	if not self._containersToInitializeSet[container] then
		self._containersToInitializeSet[container] = true
		table.insert(self._containersToInitializeList, container)
	end
end

--[=[
	Initializes the container provider. Should be done via [ServiceBag].
]=]
function TemplateProvider:Init()
	assert(not self._initialized, "Already initialized")

	self._maid = Maid.new()
	self._initialized = true
	self._registry = {} -- [name] = rawTemplate
	self._containersSet = {} -- [parentOrAssetId] = true

	self._promises = {} -- [name]  = Promise

	for _, container in pairs(self._containersToInitializeList) do
		self:AddContainer(container)
	end
end

--[=[
	Promises to clone the template as soon as it exists.
	@param templateName string
	@return Promise<Instance>
]=]
function TemplateProvider:PromiseClone(templateName)
	assert(type(templateName) == "string", "templateName must be a string")

	self:_verifyInit()

	local template = self._registry[templateName]
	if template then
		return Promise.resolved(self:Clone(templateName))
	end

	if not self._promises[templateName] then
		local promise = Promise.new()
		self._promises[templateName] = promise

		-- Make sure to clean up the promise afterwards
		self._maid[promise] = promise
		promise:Then(function()
			self._maid[promise] = nil
		end)

		task.delay(5, function()
			if promise:IsPending() then
				warn(("[TemplateProvider.PromiseClone] - May fail to replicate template %q from cloud. %s")
					:format(templateName, self:_getReplicationHint()))
			end
		end)
	end

	return self._promises[templateName]
		:Then(function()
			-- Get a new copy
			return self:Clone(templateName)
		end)
end

function TemplateProvider:_getReplicationHint()
	local hint = ""

	if RunService:IsClient() then
		hint = "Make sure the template provider is initialized on the server."
	end

	return hint
end

--[=[
	Clones the template.

	:::info
	If the template name has a prefix of "Template" then it will remove it on the cloned instance.
	:::

	@param templateName string
	@return Instance?
]=]
function TemplateProvider:Clone(templateName)
	assert(type(templateName) == "string", "templateName must be a string")

	self:_verifyInit()

	local template = self._registry[templateName]
	if not template then
		error(("[TemplateProvider.Clone] - Cannot provide %q"):format(tostring(templateName)))
		return nil
	end

	local newItem = template:Clone()
	newItem.Name = String.removePostfix(templateName, "Template")
	return newItem
end

--[=[
	Returns the raw template

	@param templateName string
	@return Instance?
]=]
function TemplateProvider:Get(templateName)
	assert(type(templateName) == "string", "templateName must be a string")
	self:_verifyInit()

	return self._registry[templateName]
end

--[=[
	Adds a new container to the provider for provision of assets.

	@param container Instance | number
]=]
function TemplateProvider:AddContainer(container)
	assert(typeof(container) == "Instance" or type(container) == "number", "Bad container")
	self:_verifyInit()

	if not self._containersSet[container] then
		self._containersSet[container] = true
		if type(container) == "number" then
			self._maid[container] = self:_loadCloudAsset(container)
		elseif typeof(container) == "Instance" then
			self._maid[container] = self:_loadFolder(container)
		else
			error("Unknown container type to load")
		end
	end
end

--[=[
	Removes a container from the provisioning set.

	@param container Instance | number
]=]
function TemplateProvider:RemoveContainer(container)
	assert(typeof(container) == "Instance", "Bad container")
	self:_verifyInit()

	self._containersSet[container] = nil
	self._maid[container] = nil
end

--[=[
	Returns whether or not a template is registered at the time
	@param templateName string
	@return boolean
]=]
function TemplateProvider:IsAvailable(templateName)
	assert(type(templateName) == "string", "templateName must be a string")
	self:_verifyInit()

	return self._registry[templateName] ~= nil
end

--[=[
	Returns all current registered items.

	@return { Instance }
]=]
function TemplateProvider:GetAll()
	self:_verifyInit()

	local list = {}
	for _, item in pairs(self._registry) do
		table.insert(list, item)
	end

	return list
end

--[=[
	Gets all current the containers.

	@return { Instance | number }
]=]
function TemplateProvider:GetContainers()
	self:_verifyInit()

	local list = {}
	for parent, _ in pairs(self._containersSet) do
		table.insert(list, parent)
	end
	return list
end

function TemplateProvider:_verifyInit()
	if not RunService:IsRunning() then
		if not self._initialized then
			-- Initialize for hoarcecat!
			self:Init()
		end
	end

	assert(self._initialized, "TemplateProvider is not initialized")
end

function TemplateProvider:_loadCloudAsset(assetId)
	assert(type(assetId) == "number", "Bad assetId")
	local maid = Maid.new()

	-- Load on server
	if RunService:IsServer() or not RunService:IsRunning() then
		maid:GivePromise(InsertServiceUtils.promiseAsset(assetId)):Then(function(result)
			if RunService:IsRunning() then
				for _, item in pairs(result:GetChildren()) do
					-- Replicate in children
					item.Parent = self._replicationParent
				end
			else
				-- Load without parenting
				maid:GiveTask(self:_loadFolder(result))
			end
		end)
	end

	return maid
end

function TemplateProvider:_transformParent(getParent)
	if typeof(getParent) == "Instance" then
		return getParent
	elseif type(getParent) == "function" then
		local container = getParent()
		assert(typeof(container) == "Instance", "Bad container")
		return container
	else
		error("Bad getParent type")
	end
end

function TemplateProvider:_loadFolder(parent)
	local maid = Maid.new()

	-- Only connect events if we're running
	if RunService:IsRunning() then
		maid:GiveTask(parent.ChildAdded:Connect(function(child)
			self:_handleChildAdded(maid, child)
		end))
		maid:GiveTask(parent.ChildRemoved:Connect(function(child)
			self:_handleChildRemoved(maid, child)
		end))
	end

	for _, child in pairs(parent:GetChildren()) do
		self:_handleChildAdded(maid, child)
	end

	maid:GiveTask(function()
		maid:DoCleaning()

		-- Deregister children
		for _, child in pairs(parent:GetChildren()) do
			self:_handleChildRemoved(maid, child)
		end
	end)

	return maid
end

function TemplateProvider:_handleChildRemoved(maid, child)
	maid[child] = nil
	self:_removeFromRegistry(child)
end

function TemplateProvider:_handleChildAdded(maid, child)
	if child:IsA("Folder") then
		maid[child] = self:_loadFolder(child)
	else
		self:_addToRegistery(child)
	end
end

function TemplateProvider:_addToRegistery(child)
	local childName = child.Name
	-- if self._registry[childName] then
		-- warn(("[TemplateProvider._addToRegistery] - Duplicate %q in registery. Overridding")
		-- 	:format(childName))
	-- end

	self._registry[childName] = child

	if self._promises[childName] then
		self._promises[childName]:Resolve(child)
		self._promises[childName] = nil
	end
end

function TemplateProvider:_removeFromRegistry(child)
	local childName = child.Name

	if self._registry[childName] == child then
		self._registry[childName] = nil
	end
end

--[=[
	Cleans up the provider
]=]
function TemplateProvider:Destroy()
	self._maid:DoCleaning()
end

return TemplateProvider