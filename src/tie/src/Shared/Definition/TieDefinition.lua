--[=[
	@class TieDefinition
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

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
local TieRealms = require("TieRealms")
local TieSignalDefinition = require("TieSignalDefinition")
local ValueObject = require("ValueObject")

local UNSET_VALUE = Symbol.named("unsetValue")

local TieDefinition = {}
TieDefinition.ClassName = "TieDefinition"
TieDefinition.__index = TieDefinition

TieDefinition.Types = Table.readonly({
	METHOD = Symbol.named("method");
	SIGNAL = Symbol.named("signal");
	PROPERTY = Symbol.named("property"); -- will default to nil
})

TieDefinition.Realms = TieRealms

function TieDefinition.new(definitionName, members, isSharedDefinition)
	local self = setmetatable({}, TieDefinition)

	self._definitionName = assert(definitionName, "No definitionName")
	self._memberMap = {}

	self._isSharedDefinition = isSharedDefinition

	self:_addMembers(members, TieDefinition.Realms.SHARED)

	return self
end

function TieDefinition:_addMembers(members, realm)
	for memberName, memberTypeOrDefaultValue in pairs(members) do
		if memberName == TieRealms.CLIENT then
			self:_addMembers(memberTypeOrDefaultValue, TieRealms.CLIENT)
		elseif memberName == TieRealms.SERVER then
			self:_addMembers(memberTypeOrDefaultValue, TieRealms.SERVER)
		else
			assert(type(memberName) == "string", "Bad memberName")

			self:_addMember(memberName, memberTypeOrDefaultValue, realm)
		end
	end
end

function TieDefinition:_addMember(memberName, memberTypeOrDefaultValue, realm)
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
	@return { TieInterface }
]=]
function TieDefinition:GetImplementations(adornee: Instance)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local implementations = {}

	local containerName = self:GetContainerName()
	for _, item in pairs(adornee:GetChildren()) do
		if item.Name == containerName then
			if self:IsImplementation(item) then
				table.insert(implementations, TieInterface.new(self, item, nil))
			end
		end
	end

	return implementations
end

--[=[
	Observes all the children implementations for this adornee

	@param adornee Instance
	@return Observable<Brio<TieInterface>>
]=]
function TieDefinition:ObserveChildrenBrio(adornee: Instance)
	return RxInstanceUtils.observeChildrenBrio(adornee):Pipe({
		RxBrioUtils.flatMapBrio(function(child)
			return self:ObserveBrio(child)
		end)
	})
end

--[=[
	Promises the implementation

	@param adornee Adornee
	@return Promise<TieInterface>
]=]
function TieDefinition:Promise(adornee)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	-- TODO: Support cancellation cleanup here.

	return Rx.toPromise(self:Observe(adornee):Pipe({
		Rx.where(function(value)
			return value ~= nil
		end)
	}))
end

--[=[
	Gets all valid interfaces for this adornee's children

	@param adornee Instance
	@return { TieInterface }
]=]
function TieDefinition:GetChildren(adornee: Instance)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local implementations = {}

	-- TODO: Make this faster
	for _, item in pairs(adornee:GetChildren()) do
		for _, option in pairs(self:GetImplementations(item)) do
			table.insert(implementations, option)
		end
	end

	return implementations
end

--[=[
	Finds the implementation on the adornee. Alais for [FindFirstImplementation]

	@param adornee Adornee
	@return TieInterface | nil
]=]
function TieDefinition:Find(adornee: Instance)
	return self:FindFirstImplementation(adornee)
end

--[=[
	Observes all implementations that are tagged with the given tag name

	@param tagName string
	@return TieInterface | nil
]=]
function TieDefinition:ObserveAllTaggedBrio(tagName)
	assert(type(tagName) == "string", "Bad tagName")

	return RxCollectionServiceUtils.observeTaggedBrio(tagName):Pipe({
		RxBrioUtils.flatMapBrio(function(instance)
			return self:ObserveBrio(instance)
		end)
	})
end

--[=[
	Finds the first valid interfaces for this adornee
	@param adornee Instance
	@return TieInterface
]=]
function TieDefinition:FindFirstImplementation(adornee: Instance)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local containerName = self:GetContainerName()
	for _, item in pairs(adornee:GetChildren()) do
		if item.Name == containerName then
			if self:IsImplementation(item) then
				return TieInterface.new(self, item, nil)
			end
		end
	end

	return nil
end

--[=[
	Returns true if the adornee implements the interface, and false otherwise.
	@param adornee Instance
	@return boolean
]=]
function TieDefinition:HasImplementation(adornee: Instance)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local folder = adornee:FindFirstChild(self:GetContainerName())
	if not folder then
		return false
	end

	return self:IsImplementation(folder)
end

--[=[
	Observes whether the adornee implements the interface.
	@param adornee Instance
	@return Observable<boolean>>
]=]
function TieDefinition:ObserveIsImplemented(adornee: Instance): boolean
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return self:ObserveLastImplementationBrio(adornee)
		:Pipe({
			RxBrioUtils.map(function(result)
				return result and true or false
			end);
			RxBrioUtils.emitOnDeath(false);
			Rx.defaultsTo(false);
			Rx.distinct();
		})
end

--[=[
	Observes whether the folder is a valid implementation
	@param folder Instance
	@return Observable<boolean>>
]=]
function TieDefinition:ObserveIsImplementation(folder: Folder)
	return self:_observeImplementation(folder)
		:Pipe({
			RxBrioUtils.map(function(result)
				return result and true or false
			end);
			RxBrioUtils.emitOnDeath(false);
			Rx.defaultsTo(false);
			Rx.distinct();
		})
end

--[=[
	Observes whether the folder is a valid implementation on the given adornee
	@param folder Instance
	@param adornee Instance
	@return Observable<boolean>>
]=]
function TieDefinition:ObserveIsImplementedOn(folder: Folder, adornee: Instance)
	assert(typeof(folder) == "Instance", "Bad folder")
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return RxInstanceUtils.observePropertyBrio(folder, "Parent", function(parent)
		return parent == adornee
	end):Pipe({
		RxBrioUtils.switchMapBrio(function()
			return self:_observeImplementation(folder)
		end);
		RxBrioUtils.map(function(result)
			return result and true or false
		end);
		RxBrioUtils.emitOnDeath(false);
		Rx.defaultsTo(false);
		Rx.distinct();
	})
end

--[=[
	Observes a valid implementation wrapped in a brio if it exists.
	@param adornee Instance
	@return Observable<Brio<TieImplementation<T>>>
]=]
function TieDefinition:ObserveLastImplementationBrio(adornee: Instance)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return RxInstanceUtils.observeLastNamedChildBrio(adornee, "Folder", self:GetContainerName())
		:Pipe({
			RxBrioUtils.switchMapBrio(function(folder)
				return self:_observeImplementation(folder)
			end);
			RxBrioUtils.onlyLastBrioSurvives();
		})
end

function TieDefinition:ObserveBrio(adornee: Instance)
	return self:ObserveLastImplementationBrio(adornee)
end

--[=[
	Observes a valid implementation if it exists, or nil

	@param adornee Instance
	@return Observable<TieImplementation<T> | nil>>
]=]
function TieDefinition:ObserveLastImplementation(adornee: Instance)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return self:ObserveLastImplementationBrio(adornee):Pipe({
		RxStateStackUtils.topOfStack();
	})
end

function TieDefinition:Observe(adornee: Instance)
	return self:ObserveLastImplementation(adornee)
end

--[=[
	Observes valid implementations wrapped in a brio if it exists.
	@param adornee Instance
	@return Observable<Brio<TieImplementation<T>>>
]=]
function TieDefinition:ObserveImplementationsBrio(adornee: Instance)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return RxInstanceUtils.observeChildrenOfNameBrio(adornee, "Folder", self:GetContainerName())
		:Pipe({
			RxBrioUtils.flatMapBrio(function(folder)
				return self:_observeImplementation(folder)
			end)
		})
end

function TieDefinition:_observeImplementation(folder)
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
					local brio = Brio.new(TieInterface.new(self, folder, nil))
					sub:Fire(brio)
					maid._brio = brio
				else
					maid._brio = nil
				end
			end))

			function update()
				isImplemented.Value = self:IsImplementation(folder)
			end
		end

		maid:GiveTask(folder.ChildAdded:Connect(function(child)
			maid[child] = child:GetPropertyChangedSignal("Name"):Connect(update)
			update()
		end))

		for memberName, member in pairs(self:GetMemberMap()) do
			if not member:IsAllowed() then
				continue
			end

			if member.ClassName == "TiePropertyDefinition" then
				maid:GiveTask(folder:GetAttributeChangedSignal(memberName):Connect(update))
			end
		end

		maid:GiveTask(folder.ChildRemoved:Connect(function(child)
			maid[child] = nil
			update()
		end))

		for _, child in pairs(folder:GetChildren()) do
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
	@return TieImplementation<T>
]=]
function TieDefinition:Implement(adornee: Instance, implementer)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(type(implementer) == "table" or implementer == nil, "Bad implementer")

	return TieImplementation.new(self, adornee, implementer)
end

--[=[
	Gets an interface to the tie definition. Not this can be done
	on any Roblox instance. If the instance does not implement the interface,
	invoking interface methods, or querying the interface will result
	in errors.

	@param adornee Instance -- Adornee to get interface on
	@return TieInterface<T>
]=]
function TieDefinition:Get(adornee: Instance)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return TieInterface.new(self, nil, adornee)
end

--[=[
	Gets the name of the definition
	@return string
]=]
function TieDefinition:GetName(): string
	return self._definitionName
end

function TieDefinition:GetContainerNameForServer()
	return self._definitionName
end

function TieDefinition:GetContainerName(): string
	if RunService:IsClient() and not self._isSharedDefinition then
		return self._definitionName .. "Client"
	else
		return self._definitionName
	end
end

function TieDefinition:GetMemberMap()
	return self._memberMap
end

--[=[
	Returns true if the folder is an implementation

	@param folder Folder
	@return boolean
]=]
function TieDefinition:IsImplementation(folder)
	assert(typeof(folder) == "Instance", "Bad folder")

	local attributes = folder:GetAttributes()
	local children = {}
	for _, item in pairs(folder:GetChildren()) do
		children[item.Name] = item
	end

	for memberName, member in pairs(self:GetMemberMap()) do
		if not member:IsRequired() then
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