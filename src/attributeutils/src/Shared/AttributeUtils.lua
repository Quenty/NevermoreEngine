--!strict
--[=[
	Provides utility functions to work with attributes in Roblox
	@class AttributeUtils
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local CancelToken = require("CancelToken")
local Maid = require("Maid")
local Promise = require("Promise")

local AttributeUtils = {}

--[=[
	Predicate run against the current value of an attribute.
	@type AttributePredicate (value: any) -> boolean
	@within AttributeUtils
]=]
export type AttributePredicate = (value: any) -> boolean

--[=[
	Subset of the [Binder] API that [AttributeUtils.bindToBinder] needs. Declared
	structurally since this package cannot depend upon the binder package.

	@type BinderLike { Bind: (self: any, inst: Instance) -> any, ... }
	@within AttributeUtils
]=]
export type BinderLike = {
	Bind: (self: any, inst: Instance) -> any,
	BindClient: (self: any, inst: Instance) -> (),
	Unbind: (self: any, inst: Instance) -> (),
	UnbindClient: (self: any, inst: Instance) -> (),
	Get: (self: any, inst: Instance) -> any,
	ObserveInstance: (self: any, inst: Instance, callback: (any) -> ()) -> () -> (),
}

local DEFAULT_PREDICATE: AttributePredicate = function(value)
	return value ~= nil
end

type ValidAttributeMap = { [string]: true }

local VALID_ATTRIBUTE_TYPES: ValidAttributeMap = table.freeze({
	["nil"] = true,
	["string"] = true,
	["boolean"] = true,
	["number"] = true,
	["UDim"] = true,
	["UDim2"] = true,
	["BrickColor"] = true,
	["CFrame"] = true,
	["Color3"] = true,
	["Vector2"] = true,
	["Vector3"] = true,
	["NumberSequence"] = true,
	["ColorSequence"] = true,
	["IntValue"] = true,
	["NumberRange"] = true,
	["Rect"] = true,
	["Font"] = true,
	["EnumItem"] = true,
} :: ValidAttributeMap)

--[=[
	Returns whether the attribute is a valid type or not for an attribute.

	```lua
	print(AttributeUtils.isValidAttributeType(typeof("hi"))) --> true
	```

	@param valueType string
	@return boolean
]=]
function AttributeUtils.isValidAttributeType(valueType: string): boolean
	return VALID_ATTRIBUTE_TYPES[valueType] == true
end

--[=[
	Promises attribute value fits predicate

	@param instance Instance
	@param attributeName string
	@param predicate AttributePredicate?
	@param cancelToken CancelToken?
	@return Promise<unknown>
]=]
function AttributeUtils.promiseAttribute(
	instance: Instance,
	attributeName: string,
	predicate: AttributePredicate?,
	cancelToken: CancelToken.CancelToken?
): Promise.Promise<unknown>
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(attributeName) == "string", "Bad attributeName")
	assert(type(predicate) == "function" or predicate == nil, "Bad predicate")
	assert(CancelToken.isCancelToken(cancelToken) or cancelToken == nil, "Bad cancelToken")

	local checkValue: AttributePredicate = predicate or DEFAULT_PREDICATE

	do
		local attributeValue = instance:GetAttribute(attributeName)
		if checkValue(attributeValue) then
			return Promise.resolved(attributeValue)
		end
	end

	local promise = Promise.new()
	local maid = Maid.new()
	maid:GiveTask(promise)

	if cancelToken then
		maid:GiveTask(cancelToken.Cancelled:Connect(function()
			promise:Reject()
		end))
	end

	maid:GiveTask(instance:GetAttributeChangedSignal(attributeName):Connect(function()
		local attributeValue = instance:GetAttribute(attributeName)
		if checkValue(attributeValue) then
			promise:Resolve(attributeValue)
		end
	end))

	promise:Finally(function()
		maid:DoCleaning()
	end)

	return promise
end

--[=[
	Whenever the attribute is true, the binder will be bound, and when the
	binder is bound, the attribute will be true.

	@param instance Instance
	@param attributeName string
	@param binder Binder<T>
	@return Maid
]=]
function AttributeUtils.bindToBinder(instance: Instance, attributeName: string, binder: BinderLike): Maid.Maid
	assert(binder, "Bad binder")
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(attributeName) == "string", "Bad attributeName")

	local maid = Maid.new()

	local function syncAttribute()
		if instance:GetAttribute(attributeName) then
			if RunService:IsClient() then
				binder:BindClient(instance)
			else
				binder:Bind(instance)
			end
		else
			if RunService:IsClient() then
				binder:UnbindClient(instance)
			else
				binder:Unbind(instance)
			end
		end
	end
	maid:GiveTask(instance:GetAttributeChangedSignal(attributeName):Connect(syncAttribute))

	local function syncBoundClass()
		if binder:Get(instance) then
			instance:SetAttribute(attributeName, true)
		else
			instance:SetAttribute(attributeName, false)
		end
	end
	maid:GiveTask(binder:ObserveInstance(instance, syncBoundClass))

	if binder:Get(instance) or instance:GetAttribute(attributeName) then
		instance:SetAttribute(attributeName, true)
		if RunService:IsClient() then
			binder:BindClient(instance)
		else
			binder:Bind(instance)
		end
	else
		instance:SetAttribute(attributeName, false)
		-- no need to bind
	end

	-- Depopuplate the attribute on exit
	maid:GiveTask(function()
		-- Force all cleaning first
		maid:DoCleaning()

		-- Cleanup
		instance:SetAttribute(attributeName, nil)
	end)

	return maid
end

--[=[
	Initializes an attribute for a given instance

	@param instance Instance
	@param attributeName string
	@param default T
	@return T -- The value of the attribute
]=]
function AttributeUtils.initAttribute<T>(instance: Instance, attributeName: string, default: T): T
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(typeof(attributeName) == "string", "Bad attributeName")

	local value = instance:GetAttribute(attributeName)
	if value == nil then
		instance:SetAttribute(attributeName, default :: any)
		return default
	end

	return value :: any
end

--[=[
	Retrieves an attribute, and if it is nil, returns the default
	instead.
	@param instance Instance
	@param attributeName string
	@param default T
	@return T
]=]
function AttributeUtils.getAttribute<T>(instance: Instance, attributeName: string, default: T): T
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(attributeName) == "string", "Bad attributeName")

	local value = instance:GetAttribute(attributeName)
	if value == nil then
		return default
	end

	return value :: any
end

--[=[
	Removes all attributes from an instance.

	@param instance Instance
]=]
function AttributeUtils.removeAllAttributes(instance: Instance): ()
	assert(typeof(instance) == "Instance", "Bad instance")

	for key, _ in instance:GetAttributes() do
		instance:SetAttribute(key, nil)
	end
end

return AttributeUtils
