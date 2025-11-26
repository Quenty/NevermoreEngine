--[=[
	Constructs a new interface declaration which allows for interface usage
	between both Roblox API users and OOP users, as well as without accessing a
	[ServiceBag].

	Also allows for extensibility via implementing interfaces.

	```lua
	local require = require(script.Parent.loader).load(script)

	local TieDefinition = require("TieDefinition")

	return TieDefinition.new("GlobalLeaderboard", {
		-- Modification
		[TieDefinition.Realms.SERVER] = {
			RemoveAllEntries = TieDefinition.Types.METHOD;
			SetEntryValueForUserId = TieDefinition.Types.METHOD;
			IncrementEntryForUserId = TieDefinition.Types.METHOD;
			CreateEntry = TieDefinition.Types.METHOD;
		};

		-- List
		ObserveEntriesBrio = TieDefinition.Types.METHOD;
		GetEntryList = TieDefinition.Types.METHOD;

		-- Single
		ObserveEntryByUserId = TieDefinition.Types.METHOD;
		GetEntryForUserId = TieDefinition.Types.METHOD;

		-- Plural
		ObserveEntriesByUserIdBrio = TieDefinition.Types.METHOD;
		GetEntriesForUserId = TieDefinition.Types.METHOD;

		-- Rendering
		ObserveTopCount = TieDefinition.Types.METHOD;
		ObserveFormatType = TieDefinition.Types.METHOD;
		ObserveTitleTranslationKey = TieDefinition.Types.METHOD;
		ObserveEntryTranslationKey = TieDefinition.Types.METHOD;
	})
	```

	@class TieDefinition
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxCollectionServiceUtils = require("RxCollectionServiceUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local RxStateStackUtils = require("RxStateStackUtils")
local String = require("String")
local Symbol = require("Symbol")
local Table = require("Table")
local TieImplementation = require("TieImplementation")
local TieInterface = require("TieInterface")
local TieMethodDefinition = require("TieMethodDefinition")
local TiePropertyDefinition = require("TiePropertyDefinition")
local TieRealmUtils = require("TieRealmUtils")
local TieRealms = require("TieRealms")
local TieSignalDefinition = require("TieSignalDefinition")
local ValueObject = require("ValueObject")

local UNSET_VALUE = Symbol.named("unsetValue")

export type TieRealm = TieRealms.TieRealm

local TieDefinition = {}
TieDefinition.ClassName = "TieDefinition"
TieDefinition.__index = TieDefinition

TieDefinition.Types = Table.readonly({
	METHOD = Symbol.named("method"),
	SIGNAL = Symbol.named("signal"),
	PROPERTY = Symbol.named("property"), -- will default to nil
})

TieDefinition.Realms = TieRealms

--[=[
	Constructs a new TieDefinition with the given members

	@param definitionName string
	@param members any
	@return TieDefinition
]=]
function TieDefinition.new(definitionName: string, members)
	local self = setmetatable({}, TieDefinition)

	self._definitionName = assert(definitionName, "No definitionName")
	self._validContainerNameSetWeakCache = setmetatable({}, { __mode = "kv" })
	self._memberMap = {}
	self._defaultTieRealm = TieRealms.SHARED

	-- Start in shared world
	self:_addMembers(members, TieRealms.SHARED)

	self.Server = setmetatable({
		_defaultTieRealm = TieRealms.SERVER,
	}, {
		__index = self,
	})

	self.Client = setmetatable({
		_defaultTieRealm = TieRealms.CLIENT,
	}, {
		__index = self,
	})

	return self
end

function TieDefinition:_addMembers(members, realm)
	for memberName, memberTypeOrDefaultValue in members do
		if TieRealmUtils.isTieRealm(memberName) then
			self:_addMembers(memberTypeOrDefaultValue, memberName)
		elseif type(memberName) == "string" then
			self:_addMember(memberName, memberTypeOrDefaultValue, realm)
		else
			error(
				string.format(
					"[TieDefinition] - Bad memberName %q, expected either string or TieRealm.",
					tostring(memberName)
				)
			)
		end
	end
end

function TieDefinition:_addMember(memberName: string, memberTypeOrDefaultValue, realm: TieRealm)
	if memberTypeOrDefaultValue == TieDefinition.Types.METHOD then
		self._memberMap[memberName] = TieMethodDefinition.new(self, memberName, realm)
	elseif memberTypeOrDefaultValue == TieDefinition.Types.SIGNAL then
		self._memberMap[memberName] = TieSignalDefinition.new(self, memberName, realm)
	elseif memberTypeOrDefaultValue == TieDefinition.Types.PROPERTY then
		self._memberMap[memberName] = TiePropertyDefinition.new(self, memberName, nil, realm)
	else
		self._memberMap[memberName] = TiePropertyDefinition.new(self, memberName, memberTypeOrDefaultValue, realm)
	end
end

--[=[
	Gets all valid interfaces for this adornee
	@param adornee Instance
	@param tieRealm TieRealm?
	@return { TieInterface }
]=]
function TieDefinition:GetImplementations(adornee: Instance, tieRealm: TieRealm?)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	tieRealm = tieRealm or self._defaultTieRealm

	local implementations = {}

	for _, item in self:GetImplementationParents(adornee, tieRealm) do
		table.insert(implementations, TieInterface.new(self, item, nil, tieRealm))
	end

	return implementations
end

function TieDefinition:GetNewImplClass(tieRealm: TieRealm): string
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	if tieRealm == TieRealms.CLIENT then
		return "Configuration"
	else
		return "Camera"
	end
end

local IMPL_CLIENT_SET = table.freeze({
	["Configuration"] = true,
})

local IMPL_SERVER_SET = table.freeze({
	["Camera"] = true,
})

local IMPL_SHARED_SET = table.freeze({
	["Camera"] = true,
	["Configuration"] = true,
})

function TieDefinition:GetImplClassSet(tieRealm: TieRealm): { [string]: boolean }
	if tieRealm == TieRealms.CLIENT then
		-- Shared implements both...
		return IMPL_CLIENT_SET
	elseif tieRealm == TieRealms.SERVER then
		return IMPL_SERVER_SET
	elseif tieRealm == TieRealms.SHARED then
		return IMPL_SHARED_SET
	else
		error("Unknwon tieRealm")
	end
end

function TieDefinition:GetImplementationParents(adornee: BasePart, tieRealm: TieRealm?): { Instance }
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	tieRealm = tieRealm or self._defaultTieRealm

	local validContainerNameSet = self:GetValidContainerNameSet(tieRealm)

	local implParents = {}

	for _, implParent in adornee:GetChildren() do
		if validContainerNameSet[implParent.Name] then
			if self:IsImplementation(implParent) then
				table.insert(implParents, implParent)
			end
		end
	end

	return implParents
end

--[=[
	Observes all the children implementations for this adornee

	@param adornee Instance
	@param tieRealm TieRealm?
	@return Observable<Brio<TieInterface>>
]=]
function TieDefinition:ObserveChildrenBrio(adornee: Instance, tieRealm: TieRealm?)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	return RxInstanceUtils.observeChildrenBrio(adornee):Pipe({
		RxBrioUtils.flatMapBrio(function(child)
			return self:ObserveBrio(child, tieRealm)
		end),
	})
end

--[=[
	Promises the implementation

	@param adornee Adornee
	@param tieRealm TieRealm?
	@return Promise<TieInterface>
]=]
function TieDefinition:Promise(adornee: Instance, tieRealm: TieRealm?)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	-- TODO: Support cancellation cleanup here.

	return Rx.toPromise(self:Observe(adornee, tieRealm):Pipe({
		Rx.where(function(value)
			return value ~= nil
		end),
	}))
end

function TieDefinition:Wait(adornee: Instance, tieRealm: TieRealm?)
	return self:Promise(adornee, tieRealm):Wait()
end

--[=[
	Gets all valid interfaces for this adornee's children

	@param adornee Instance
	@param tieRealm TieRealm?
	@return { TieInterface }
]=]
function TieDefinition:GetChildren(adornee: Instance, tieRealm: TieRealm?)
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local implementations = {}

	-- TODO: Make this faster
	for _, item in adornee:GetChildren() do
		for _, option in self:GetImplementations(item, tieRealm) do
			table.insert(implementations, option)
		end
	end

	return implementations
end

--[=[
	Finds the implementation on the adornee. Alais for [FindFirstImplementation]

	@param adornee Adornee
	@param tieRealm TieRealm?
	@return TieInterface | nil
]=]
function TieDefinition:Find(adornee: Instance, tieRealm: TieRealm?)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	return self:FindFirstImplementation(adornee, tieRealm)
end

--[=[
	Observes all implementations that are tagged with the given tag name

	@param tagName string
	@param tieRealm TieRealm?
	@return TieInterface | nil
]=]
function TieDefinition:ObserveAllTaggedBrio(tagName: string, tieRealm: TieRealm?)
	assert(type(tagName) == "string", "Bad tagName")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	return RxCollectionServiceUtils.observeTaggedBrio(tagName):Pipe({
		RxBrioUtils.flatMapBrio(function(instance)
			return self:ObserveBrio(instance, tieRealm)
		end),
	})
end

--[=[
	Finds the first valid interfaces for this adornee
	@param adornee Instance
	@param tieRealm TieRealm?
	@return TieInterface
]=]
function TieDefinition:FindFirstImplementation(adornee: Instance, tieRealm: TieRealm?)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	tieRealm = tieRealm or self._defaultTieRealm

	local validContainerNameSet = self:GetValidContainerNameSet(tieRealm)
	for _, item in adornee:GetChildren() do
		if validContainerNameSet[item.Name] then
			if self:IsImplementation(item, tieRealm) then
				return TieInterface.new(self, item, nil, tieRealm)
			end
		end
	end

	return nil
end

--[=[
	Returns true if the adornee implements the interface, and false otherwise.
	@param adornee Instance
	@param tieRealm TieRealm?
	@return boolean
]=]
function TieDefinition:HasImplementation(adornee: Instance, tieRealm: TieRealm?)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	tieRealm = tieRealm or self._defaultTieRealm

	-- TODO: Maybe something faster
	for containerName, _ in pairs(self:GetValidContainerNameSet(tieRealm)) do
		local implParent = adornee:FindFirstChild(containerName)
		if not implParent then
			continue
		end

		if self:IsImplementation(implParent, tieRealm) then
			return true
		end
	end

	return false
end

--[=[
	Observes whether the adornee implements the interface.
	@param adornee Instance
	@param tieRealm TieRealm?
	@return Observable<boolean>>
]=]
function TieDefinition:ObserveIsImplemented(adornee: Instance, tieRealm: TieRealm?): Observable.Observable<boolean>
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	return self:ObserveLastImplementationBrio(adornee, tieRealm):Pipe({
		RxBrioUtils.map(function(result)
			return result and true or false
		end),
		RxBrioUtils.emitOnDeath(false),
		Rx.defaultsTo(false) :: any,
		Rx.distinct() :: any,
	})
end

--[=[
	Observes whether the implParent is a valid implementation
	@param implParent Instance
	@param tieRealm TieRealm?
	@return Observable<boolean>>
]=]
function TieDefinition:ObserveIsImplementation(
	implParent: Instance,
	tieRealm: TieRealm?
): Observable.Observable<boolean>
	assert(typeof(implParent) == "Instance", "Bad implParent")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	tieRealm = tieRealm or self._defaultTieRealm

	return self:_observeImplementation(implParent, tieRealm):Pipe({
		RxBrioUtils.map(function(result)
			return result and true or false
		end),
		RxBrioUtils.emitOnDeath(false),
		Rx.defaultsTo(false),
		Rx.distinct(),
	})
end

--[=[
	Observes whether the implParent is a valid implementation on the given adornee
	@param implParent Instance
	@param adornee Instance
	@param tieRealm TieRealm?
	@return Observable<boolean>>
]=]
function TieDefinition:ObserveIsImplementedOn(
	implParent: Instance,
	adornee: Instance,
	tieRealm: TieRealm?
): Observable.Observable<boolean>
	assert(typeof(implParent) == "Instance", "Bad implParent")
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	tieRealm = tieRealm or self._defaultTieRealm

	return RxInstanceUtils.observePropertyBrio(implParent, "Parent", function(parent)
		return parent == adornee
	end):Pipe({
		RxBrioUtils.switchMapBrio(function()
			return self:_observeImplementation(implParent, tieRealm)
		end),
		RxBrioUtils.map(function(result)
			return result and true or false
		end),
		RxBrioUtils.emitOnDeath(false),
		Rx.defaultsTo(false),
		Rx.distinct(),
	})
end

--[=[
	Observes a valid implementation wrapped in a brio if it exists.

	@param adornee Instance
	@param tieRealm TieRealm?
	@return Observable<Brio<TieImplementation<T>>>
]=]
function TieDefinition:ObserveBrio(adornee: Instance, tieRealm: TieRealm?)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	tieRealm = tieRealm or self._defaultTieRealm

	return self:ObserveValidContainerChildrenBrio(adornee, tieRealm):Pipe({
		RxBrioUtils.switchMapBrio(function(implParent)
			return self:_observeImplementation(implParent, tieRealm)
		end),
		RxBrioUtils.onlyLastBrioSurvives(),
	})
end

--[=[
	Observes a valid implementation if it exists, or nil

	@param adornee Instance
	@param tieRealm TieRealm?
	@return Observable<TieImplementation<T> | nil>>
]=]
function TieDefinition:Observe(adornee: Instance, tieRealm: TieRealm?)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	return self:ObserveBrio(adornee, tieRealm):Pipe({
		RxStateStackUtils.topOfStack(),
	})
end

TieDefinition.ObserveLastImplementation = TieDefinition.Observe
TieDefinition.ObserveLastImplementationBrio = TieDefinition.ObserveBrio

--[=[
	Observes valid implementations wrapped in a brio if it exists.
	@param adornee Instance
	@param tieRealm TieRealm?
	@return Observable<Brio<TieImplementation<T>>>
]=]
function TieDefinition:ObserveImplementationsBrio(adornee: Instance, tieRealm: TieRealm?)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	tieRealm = tieRealm or self._defaultTieRealm

	return self:ObserveValidContainerChildrenBrio(adornee, tieRealm):Pipe({
		RxBrioUtils.flatMapBrio(function(implParent)
			return self:_observeImplementation(implParent, tieRealm)
		end),
	})
end

function TieDefinition:ObserveValidContainerChildrenBrio(adornee: Instance, tieRealm: TieRealm?)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	local validContainerNameSet = self:GetValidContainerNameSet(tieRealm)
	local validImplClassSet = self:GetImplClassSet(tieRealm)

	return RxInstanceUtils.observeChildrenBrio(adornee, function(value)
		-- Just assume our name doesn't change
		return validImplClassSet[value.ClassName] and validContainerNameSet[value.Name] and true or false
	end)
end

function TieDefinition:_observeImplementation(implParent: Instance, tieRealm: TieRealm?)
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	return Observable.new(function(sub)
		-- Bind to all children, instead of individually. This is a
		-- performance gain.

		local maid = Maid.new()

		local update
		do
			local isImplemented = maid:Add(ValueObject.new(UNSET_VALUE))

			maid:GiveTask(isImplemented.Changed:Connect(function()
				maid._brio = nil

				if not sub:IsPending() then
					return
				end

				if isImplemented.Value then
					local brio = Brio.new(TieInterface.new(self, implParent, nil, tieRealm))
					sub:Fire(brio)
					maid._brio = brio
				else
					maid._brio = nil
				end
			end))

			function update()
				isImplemented.Value = self:IsImplementation(implParent, tieRealm)
			end
		end

		maid:GiveTask(implParent.ChildAdded:Connect(function(child)
			maid[child] = child:GetPropertyChangedSignal("Name"):Connect(update)
			update()
		end))

		for memberName, member in self._memberMap do
			if not member:IsAllowedOnInterface(tieRealm) then
				continue
			end

			if member.ClassName == "TiePropertyDefinition" then
				maid:GiveTask(implParent:GetAttributeChangedSignal(memberName):Connect(update))
			end
		end

		maid:GiveTask(implParent.ChildRemoved:Connect(function(child)
			maid[child] = nil
			update()
		end))

		for _, child in implParent:GetChildren() do
			maid[child] = child:GetPropertyChangedSignal("Name"):Connect(update)
		end

		update()

		return maid
	end)
end

--[=[
	Ensures implementation of the object, binding table values and Lua OOP objects
	to Roblox objects that can be invoked generally.

	```lua

	```

	@param adornee Instance -- Adornee to implement interface on
	@param implementer table? -- Table with all interface values or nil
	@param tieRealm TieRealm?
	@return TieImplementation<T>
]=]
function TieDefinition:Implement(adornee: Instance, implementer, tieRealm: TieRealm?)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(type(implementer) == "table" or implementer == nil, "Bad implementer")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	tieRealm = tieRealm or self._defaultTieRealm

	return TieImplementation.new(self, adornee, implementer, tieRealm)
end

--[=[
	Gets an interface to the tie definition. Not this can be done
	on any Roblox instance. If the instance does not implement the interface,
	invoking interface methods, or querying the interface will result
	in errors.

	:::tip
	Probably use :Find() instead of Get, since this always returns an interface.
	:::

	@param adornee Instance -- Adornee to get interface on
	@param tieRealm TieRealm?
	@return TieInterface<T>
]=]
function TieDefinition:Get(adornee: Instance, tieRealm: TieRealm?)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	tieRealm = tieRealm or self._defaultTieRealm

	return TieInterface.new(self, nil, adornee, tieRealm)
end

--[=[
	Gets the name of the definition
	@return string
]=]
function TieDefinition:GetName(): string
	return self._definitionName
end

--[=[
	Gets the valid container name set for the tie definition

	@param tieRealm TieRealm
	@return { [string]: boolean }
]=]
function TieDefinition:GetValidContainerNameSet(tieRealm: TieRealm?): { [string]: boolean }
	-- TODO: Still generate unique datamodel key here?
	if self._validContainerNameSetWeakCache[tieRealm] then
		return self._validContainerNameSetWeakCache[tieRealm]
	end

	if tieRealm == TieRealms.CLIENT then
		-- Shared implements both...
		self._validContainerNameSetWeakCache[tieRealm] = table.freeze({
			[self._definitionName .. "Client"] = true,
			[self._definitionName .. "Shared"] = true,
		})
		return self._validContainerNameSetWeakCache[tieRealm]
	elseif tieRealm == TieRealms.SERVER then
		self._validContainerNameSetWeakCache[tieRealm] = table.freeze({
			[self._definitionName] = true,
			[self._definitionName .. "Shared"] = true,
		})
		return self._validContainerNameSetWeakCache[tieRealm]
	elseif tieRealm == TieRealms.SHARED then
		-- Technically on the implementation shared is very strict,
		-- but we allow any calls here for discovery
		self._validContainerNameSetWeakCache[tieRealm] = table.freeze({
			[self._definitionName] = true,
			[self._definitionName .. "Client"] = true,
			[self._definitionName .. "Shared"] = true,
		})
		return self._validContainerNameSetWeakCache[tieRealm]
	else
		error("Unknwon tieRealm")
	end
end

--[=[
	Gets a container name for a new container. See [GetValidContainerNameSet]
	for the full set of valid container names for the tie definition.

	@param tieRealm TieRealm
	@return string
]=]
function TieDefinition:GetNewContainerName(tieRealm: TieRealm): string
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	-- TODO: Handle server/actor

	if tieRealm == TieRealms.CLIENT then
		return self._definitionName .. "Client"
	elseif tieRealm == TieRealms.SERVER then
		return self._definitionName
	elseif tieRealm == TieRealms.SHARED then
		-- Shared contains both server and client
		return self._definitionName .. "Shared"
	else
		error("Bad tieRealm")
	end
end

function TieDefinition:GetMemberMap()
	return self._memberMap
end

--[=[
	Returns true if the implParent is an implementation

	@param implParent Instance
	@param tieRealm TieRealm? -- Optional tie realm
	@return boolean
]=]
function TieDefinition:IsImplementation(implParent: Instance, tieRealm: TieRealm?): boolean
	assert(typeof(implParent) == "Instance", "Bad implParent")
	assert(TieRealmUtils.isTieRealm(tieRealm) or tieRealm == nil, "Bad tieRealm")

	tieRealm = tieRealm or self._defaultTieRealm

	local attributes = implParent:GetAttributes()
	local children = {}
	for _, item in implParent:GetChildren() do
		children[item.Name] = item
	end

	for memberName, member in self._memberMap do
		if not member:IsRequiredForInterface(tieRealm) then
			continue
		end

		local found = children[memberName]
		if not found then
			if member.ClassName == "TiePropertyDefinition" then
				if attributes[memberName] == nil then
					return false
				else
					continue
				end
			end

			return false
		end

		if member.ClassName == "TieMethodDefinition" then
			if not found:IsA("BindableFunction") then
				return false
			end
		elseif member.ClassName == "TieSignalDefinition" then
			if not found:IsA("BindableEvent") then
				return false
			end
		elseif member.ClassName == "TiePropertyDefinition" then
			if not (found:IsA("BindableFunction") or String.endsWith(found.ClassName, "Value")) then
				return false
			end
		else
			error("[TieDefinition.IsImplementation] - Unknown member type")
		end
	end

	return true
end

return TieDefinition
