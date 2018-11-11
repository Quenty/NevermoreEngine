--- General LightingManager which can tween items in lighting
-- @classmod LightingManager

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ObjectTweenManager = require("ObjectTweenManager")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local LightingManager = {}
LightingManager.__index = LightingManager
LightingManager.ClassName = "LightingManager"

function LightingManager.new()
	local self = setmetatable({}, LightingManager)

	self._objectTweenManager = ObjectTweenManager.new()

	return self
end

--- Ain't sexy, but it'll do
function LightingManager:_getObject(path)
	if not path:sub(1, #("Lighting.")) == "Lighting." then
		error("Bad path")
	end

	local base_path = path:sub(#("Lighting.") + 1)
	if base_path == "" then
		return Lighting
	end

	local current = Lighting
	for word in base_path:gmatch("%w+") do
		local new_obj = current:FindFirstChild(word)
		if not new_obj then
			warn("Unable to find " .. path)
			return nil
		end
		current = new_obj
	end

	return current
end

--- Tweens properties based upon a table with the following information
-- @param propertyTable Set of properties to tween
--[[
	{
		Priority = 0;
		Id = "BASELINE";
		Objects = {
			["Lighting"] = {
				Brightness = `Number`;
				OutdoorAmbient = `Color3`;
				FogColor = `Color3`;
				FogStart = `Number;
				FogEnd = `Number;
			};
			["Lighting.ColorCorrection"] = {
				Saturation = `Number;
				Contrast = `Number;
			};
			["Lighting.SunRays"] = {
				Intensity = `Number;
			};
		};
--]]
function LightingManager:TweenProperties(propertyTable)
	assert(propertyTable)
	assert(propertyTable.Id)
	assert(propertyTable.Objects)
	assert(propertyTable.Priority)

	local key = propertyTable.Id .. HttpService:GenerateGUID()
	local priority = propertyTable.Priority

	local objects = {}
	for path, properties in pairs(propertyTable.Objects) do
		assert(type(path) == "string")
		assert(type(properties) == "table", "Not a table")

		local object = self:_getObject(path)
		if object then
			assert(not objects[object])
			objects[object] = true
			self._objectTweenManager:TweenProperties(priority, key, object, properties)
		end
	end

	return function()
		for object, _ in pairs(objects) do
			self._objectTweenManager:RemoveTween(key, object)
		end
	end
end

function LightingManager:Destroy()
	self._objectTweenManager:Destroy()
	setmetatable(self, nil)
end

return LightingManager.new()