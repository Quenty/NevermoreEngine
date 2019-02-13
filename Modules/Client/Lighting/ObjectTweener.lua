--- Tweens properties on an object
-- @classmod ObjectTweener

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local NumberPropertyTweener = require("NumberPropertyTweener")
local Color3PropertyTweener = require("Color3PropertyTweener")
local PropertyTweenerStack = require("PropertyTweenerStack")

local DEFAULT_SPEEDS = {
	["FogEnd"] = 500;
	["FogStart"] = 500;
}

local ObjectTweener = {}
ObjectTweener.ClassName = "ObjectTweener"
ObjectTweener.__index = ObjectTweener

function ObjectTweener.new(object)
	local self = setmetatable({}, ObjectTweener)

	self._object = object or error("No object")
	self._propertyTweeners = {}

	return self
end

function ObjectTweener:RemoveTween(key)
	local to_remove = {}
	for property, propertyTweener in pairs(self._propertyTweeners) do
		propertyTweener:RemoveTween(key)
		if not propertyTweener:HasTweens() then
			to_remove[property] = true
		end
	end

	for property in pairs(to_remove) do
		self:_removePropertyTweener(property)
	end
end

function ObjectTweener:TweenProperty(priority, key, property, value)
	assert(priority)
	assert(key)
	assert(property)
	assert(value)

	local tweenerStack = self:_getPropertyTweener(property, value)
	tweenerStack:TweenProperty(priority, key, value)
end

function ObjectTweener:TweenProperties(priority, key, properties)
	assert(priority)
	assert(key)
	assert(properties)

	for property, value in pairs(properties) do
		self:TweenProperty(priority, key, property, value)
	end
end

function ObjectTweener:Update()
	local updating = false
	for _, tweener in pairs(self._propertyTweeners) do
		if tweener:Update() then
			updating = true
		end
	end
	return updating
end

function ObjectTweener:HasTweens()
	return next(self._propertyTweeners) ~= nil
end

function ObjectTweener:_removePropertyTweener(property)
	self._propertyTweeners[property] = nil
end

function ObjectTweener:_getPropertyTweener(property, value)
	if self._propertyTweeners[property] then
		return self._propertyTweeners[property]
	end

	local current_val = self._object[property]
	if typeof(current_val) ~= typeof(value) then
		error(("Bad type for property %q passed in, expected %q, got %q")
			:format(property, typeof(current_val), typeof(value)))
	end

	local base_tweener = nil
	if type(current_val) == "number" then
		base_tweener = NumberPropertyTweener.new(self._object, property)
	elseif typeof(current_val) == "Color3" then
		base_tweener = Color3PropertyTweener.new(self._object, property)
	else
		error(("Bad property type! %q"):format(type(value)))
	end

	if DEFAULT_SPEEDS[property] then
		base_tweener:SetSpeed(DEFAULT_SPEEDS[property])
	end

	local new_tweener = PropertyTweenerStack.new(base_tweener)
	self._propertyTweeners[property] = new_tweener
	return new_tweener
end

return ObjectTweener
