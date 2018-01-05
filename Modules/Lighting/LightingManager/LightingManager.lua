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

function LightingManager:TweenProperties(PropertyTable, Time)
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

function LightingManager:TweenOnItem(Parent, PropertyTable, Time)
	Time = Time or 0

	local TweenColor3Table = {}
	local DoTweenColor3 = false
	local TweenNumberTable = {}
	local DoTweenNumber = false

	for PropertyName, Value in pairs(PropertyTable) do
		if type(Value) == "table" then
			local Item = Parent:FindFirstChild(PropertyName)
			if Item then
				self:TweenOnItem(Item, Value)
			else
				warn(("[LightingManager] - No child with name of '%s'"):format(PropertyName))
			end
		elseif Color3Values[PropertyName] then
			TweenColor3Table[PropertyName] = Value
			DoTweenColor3 = true
		elseif NumberValues[PropertyName] then
			TweenNumberTable[PropertyName] = Value
			DoTweenNumber = true
		elseif BooleanValues[PropertyName] then
			Lighting[PropertyName] = Value
		elseif PropertyName == "TimeOfDay" then
			TweenTimeOfDay(Parent.TimeOfDay, Value, Time)
		else
			warn("[LightingManager] - No property with the value " .. PropertyName .. " that is tweenable")
		end
	end

	if DoTweenColor3 and Time > 0 then
		qGUI.TweenColor3(Parent, TweenColor3Table, Time, true)
	else
		for Property, Value in pairs(TweenColor3Table) do
			Parent[Property] = Value
		end
	end

	if DoTweenNumber and Time > 0 then
		qGUI.TweenTransparency(Parent, TweenNumberTable, Time, true)
	else
		for Property, Value in pairs(TweenNumberTable) do
			Parent[Property] = Value
		end
	end
end





return LightingManager
