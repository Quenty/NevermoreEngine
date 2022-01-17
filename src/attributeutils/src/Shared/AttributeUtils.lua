--[=[
	Provides utility functions to work with attributes in Roblox
	@class AttributeUtils
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Maid = require("Maid")

local AttributeUtils = {}

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

return AttributeUtils