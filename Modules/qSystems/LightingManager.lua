local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qGUI = LoadCustomLibrary("qGUI")
local qMath = LoadCustomLibrary("qMath")

local TweenTimeOfDay do
	local TweenId
	
	function TweenTimeOfDay(Start, Finish, TweenTime)
		TweenId = TweenId + 1
		local LocalTweenId = TweenId
	
		Spawn(function()
			Lighting.TimeOfDay = Finish;
			local MinutesFinish = Lighting:GetMinutesAfterMidnight()
			Lighting.TimeOfDay = Start;
			local MinutesStart = Lighting:GetMinutesAfterMidnight()
			local TimeStart = tick()
			-- print("[LIGHTING] - Tween @ "..MinutesStart.." to "..MinutesFinish.." in "..TweenTime)
	
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

local LightingManager = {} do
	local Color3Values = {
		["FogColor"] = true;
		["Ambient"] = true;
		["ColorShift_Bottom"] = true;
		["ColorShift_Top"] = true;
		["OutdoorAmbient"] = true;
		["ShadowColor"] = true;
	}
	
	local BooleanValues = {
		["Outlines"] = true;
		["GlobalShadows"] = true;
	}
	
	local NumberValues = {
		["FogEnd"] = true;
		["FogStart"] = true;
		["Brightness"] = true;
	}
	
	function LightingManager.TweenProperties(PropertyTable, Time)
		Time = Time or 0
		
		local TweenColor3Table = {}
		local DoTweenColor3 = false
		local TweenNumberTable = {}
		local DoTweenNumber = false
		
		for PropertyName, Value in pairs(PropertyTable) do
			if Color3Values[PropertyName] then
				TweenColor3Table[PropertyName] = Value
				DoTweenColor3 = true
			elseif NumberValues[PropertyName] then
				TweenNumberTable[PropertyName] = Value
				DoTweenNumber = true
			elseif BooleanValues[PropertyName] then
				Lighting[PropertyName] = Value
			elseif PropertyName == "TimeOfDay" then
				TweenTimeOfDay(Lighting.TimeOfDay, Value, Time)
			else
				error("No property with the value " .. PropertyName .. " that is tweenable")
			end
		end
		
		if DoTweenColor3 and Time > 0 then
			qGUI.TweenColor3(Lighting, TweenColor3Table, Time, true)
		else
			for Property, Value in pairs(TweenColor3Table) do
				Lighting[Property] = Value
			end
		end
		
		if DoTweenNumber and Time > 0 then
			qGUI.TweenTransparency(Lighting, TweenNumberTable, Time, true)
		else
			for Property, Value in pairs(TweenNumberTable) do
				Lighting[Property] = Value
			end
		end
	end
end

return LightingManager
