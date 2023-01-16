--[=[
	Provides utility functions to work with attributes in Roblox
	@class AttributeUtils
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Maid = require("Maid")

local AttributeUtils = {}

local VALID_ATTRIBUTE_TYPES = {
	["nil"] = true;
	["string"] = true;
	["boolean"] = true;
	["number"] = true;
	["UDim"] = true;
	["UDim2"] = true;
	["BrickColor"] = true;
	["CFrame"] = true;
	["Color3"] = true;
	["Vector2"] = true;
	["Vector3"] = true;
	["NumberSequence"] = true;
	["ColorSequence"] = true;
	["IntValue"] = true;
	["NumberRange"] = true;
	["Rect"] = true;
	["Font"] = true;
}

--[=[
	Returns whether the attribute is a valid type or not for an attribute.

	```lua
	print(AttributeUtils.isValidAttributeType(typeof("hi"))) --> true
	```

	@param valueType string
	@return boolean
]=]
function AttributeUtils.isValidAttributeType(valueType)
	return VALID_ATTRIBUTE_TYPES[valueType] == true
end

--[=[
	Whenever the attribute is true, the binder will be bound, and when the
	binder is bound, the attribute will be true.

	@param instance Instance
	@param attributeName string
	@param binder Binder<T>
	@return Maid
]=]
function AttributeUtils.bindToBinder(instance, attributeName, binder)
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
	@param default any
	@return any? -- The value of the attribute
]=]
function AttributeUtils.initAttribute(instance, attributeName, default)
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(typeof(attributeName) == "string", "Bad attributeName")

	local value = instance:GetAttribute(attributeName)
	if value == nil then
		instance:SetAttribute(attributeName, default)
		value = default
	end
	return value
end

--[=[
	Retrieves an attribute, and if it is nil, returns the default
	instead.
	@param instance Instance
	@param attributeName string
	@param default T?
	@return T?
]=]
function AttributeUtils.getAttribute(instance, attributeName, default)
	local value = instance:GetAttribute(attributeName)
	if value == nil then
		return default
	end

	return value
end

--[=[
	Removes all attributes from an instance.

	@param instance Instance
]=]
function AttributeUtils.removeAllAttributes(instance: Instance)
	assert(typeof(instance) == "Instance", "Bad instance")

	for key, _ in pairs(instance:GetAttributes()) do
		instance:SetAttribute(key, nil)
	end
end

return AttributeUtils
