--- General LightingManager which can tween items in lighting
-- @clasmod LightingManager

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Lighting = game:GetService("Lighting")

local qGUI = require("qGUI")
local qMath = require("qMath")

local TweenTimeOfDay do
	local TweenId

	function TweenTimeOfDay(Start, Finish, TweenTime)
		TweenId = TweenId + 1
		local LocalTweenId = TweenId

		spawn(function()
			Lighting.TimeOfDay = Finish;
			local MinutesFinish = Lighting:GetMinutesAfterMidnight()
			Lighting.TimeOfDay = Start;
			local MinutesStart = Lighting:GetMinutesAfterMidnight()
			local TimeStart = tick()

			while LocalTweenId == TweenId do
				if TimeStart + TweenTime <= tick() then
					Lighting:SetMinutesAfterMidnight(MinutesFinish)
					TweenId = TweenId + 1
				else
					local CurrentMinutesAfter = (tick() - TimeStart) / TweenTime
					Lighting:SetMinutesAfterMidnight(qMath.LerpNumber(MinutesStart, MinutesFinish, CurrentMinutesAfter))
				end
				wait()
			end

			if LocalTweenId == TweenId then
				Lighting.TimeOfDay = Finish;
			end
		end)
	end
end

local LightingManager = {}
LightingManager.__index = LightingManager
LightingManager.ClassName = "LightingManager"

function LightingManager.new()
	local self = setmetatable({}, LightingManager)

	return self
end

function LightingManager:TweenProperties(propertyTable, time)
	error("Not implemented. Please override.")
end

local Color3Values = {
	["FogColor"] = true;
	["Ambient"] = true;
	["ColorShift_Bottom"] = true;
	["ColorShift_Top"] = true;
	["OutdoorAmbient"] = true;
	["ShadowColor"] = true;
	["TintColor"] = true;
}

local BooleanValues = {
	["Outlines"] = true;
	["GlobalShadows"] = true;
}

local NumberValues = {
	["FogEnd"] = true;
	["FogStart"] = true;
	["Brightness"] = true;
	["Saturation"] = true;
	["Contrast"] = true;
	["Intensity"] = true;
}

function LightingManager:_tweenOnItem(parent, propertyTable, time)
	time = time or 0

	local TweenColor3Table = {}
	local DoTweenColor3 = false
	local TweenNumberTable = {}
	local DoTweenNumber = false

	for PropertyName, value in pairs(propertyTable) do
		if type(value) == "table" then
			local Item = parent:FindFirstChild(PropertyName)
			if Item then
				self:_tweenOnItem(Item, value)
			else
				warn(("[LightingManager] - No child with name of '%s'"):format(PropertyName))
			end
		elseif Color3Values[PropertyName] then
			TweenColor3Table[PropertyName] = value
			DoTweenColor3 = true
		elseif NumberValues[PropertyName] then
			TweenNumberTable[PropertyName] = value
			DoTweenNumber = true
		elseif BooleanValues[PropertyName] then
			Lighting[PropertyName] = value
		elseif PropertyName == "TimeOfDay" then
			TweenTimeOfDay(parent.TimeOfDay, value, time)
		else
			warn("[LightingManager] - No property with the value " .. PropertyName .. " that is tweenable")
		end
	end

	if DoTweenColor3 and time > 0 then
		qGUI.TweenColor3(parent, TweenColor3Table, time, true)
	else
		for property, value in pairs(TweenColor3Table) do
			parent[property] = value
		end
	end

	if DoTweenNumber and time > 0 then
		qGUI.TweenTransparency(parent, TweenNumberTable, time, true)
	else
		for property, value in pairs(TweenNumberTable) do
			parent[property] = value
		end
	end
end





return LightingManager
