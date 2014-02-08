-- This simply loads Nevermore onto the client so features client-side work. That is about it. 
-- The scripts name indicates the modular's name in ServerScriptStorage

-----------------------
-- UTILITY FUNCTIONS --
-----------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestService       = game:GetService("TestService")
local StarterPack       = game:GetService("StarterPack")
local Players           = game:GetService("Players")

local function Warn(WarningText)
	--- Used to yell at the player
	-- @param WarningText The text to warn with.

	Spawn(function()
		TestService:Warn(false, WarningText)
	end)
end

local function WaitForChild(Parent, Name)
	--- Yields until a child is added. Warns after 5 seconds of yield.
	-- @param Parent The parent to wait for the child of
	-- @param Name The name of the child
	-- @return The child found

	local Child = Parent:FindFirstChild(Name)
	local StartTime = tick()
	local Warned = false;
	while not Child do
		wait(0)
		Child = Parent:FindFirstChild(Name)
		if not Warned and StartTime + 5 <= tick() then
			Warned = true;
			Warn("[NevermoreEngineClientLoader] -" .. " " .. Name .. " has not replicated after 5 seconds, may not be able to execute Nevermore.")
		end
	end
	return Child
end

-------------
-- LOADING --
-------------

local LocalPlayer = Players.LocalPlayer

-- Wait for parent to resolve
while not script.Parent do
	wait(0)
end

-- Identify the modular script
local NevermoreModularScript = WaitForChild(ReplicatedStorage, "NevermoreEngine")
local Nevermore = require(NevermoreModularScript)