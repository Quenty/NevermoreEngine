local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qGUI              = LoadCustomLibrary("qGUI")
local qMath             = LoadCustomLibrary("qMath")

-- @author Quenty

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
	local LightingEvent = NevermoreEngine.GetRemoteEvent("ReplicateLightingEvent")
	
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
	
	local function TweenOnItem(Parent, PropertyTable, Time)
		Time = Time or 0
		
		local TweenColor3Table = {}
		local DoTweenColor3 = false
		local TweenNumberTable = {}
		local DoTweenNumber = false
		
		for PropertyName, Value in pairs(PropertyTable) do
			if type(Value) == "table" then
				local Item = Parent:FindFirstChild(PropertyName)
				if Item then
					TweenOnItem(Item, Value)
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
				warn("No property with the value " .. PropertyName .. " that is tweenable")
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
	
	local LastLightingSent 
	function LightingManager:TweenProperties(PropertyTable, Time)
		assert(type(PropertyTable) == "table")
		assert(type(Time) == "number")
		
		if RunService:IsClient() then
			TweenOnItem(Lighting, PropertyTable, Time)
		else
			LastLightingSent = {
				Table = PropertyTable, 
				EndTime = tick() + Time;
			}
			LightingEvent:FireAllClients(PropertyTable, Time)
		end
	end
	
	if RunService:IsClient() then
		LightingEvent.OnClientEvent:connect(function(PropertyTable, Time)
			LightingManager:TweenProperties(PropertyTable, Time)
		end)
	end
	
	if RunService:IsServer() then
		local function HandlePlayerAdded(Player)
			if LastLightingSent then
				LightingEvent:FireClient(Player, LastLightingSent.Table, math.max(0, tick() - LastLightingSent.EndTime))
			end
		end
		for _, Player in pairs(Players:GetPlayers()) do
			HandlePlayerAdded(Player)
		end
		Players.PlayerAdded:connect(HandlePlayerAdded)
	end
end

return LightingManager
