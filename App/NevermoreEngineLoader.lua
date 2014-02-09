--- This scripts loads Nevermore from the server.
-- It also replicates the into ReplicatedStorage for internal usage. 

-----------------------
-- UTILITY FUNCTIONS --
-----------------------

local TestService       = game:GetService('TestService')
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
			Warn("[NevermoreEngineLoader] -" .. " " .. Name .. " has not replicated after 5 seconds, may not be able to execute Nevermore.")
		end
	end
	return Child
end

-------------
-- LOADING --
-------------

-- Wait for parent to resolve
while not script.Parent do
	wait(0)
end

-- Identify the modular script
-- local NevermoreModularScript = WaitForChild(script.Parent, "NevermoreEngine")

local NevermoreModularScript = ReplicatedStorage:FindFirstChild("NevermoreEngine")
if not NevermoreModularScript then
	local NevermoreModularScriptSource = WaitForChild(script.Parent, "NevermoreEngine")

	NevermoreModularScript             = NevermoreModularScriptSource:Clone()
	NevermoreModularScript.Archivable  = false
end

local Nevermore = require(NevermoreModularScript)

-- Set identifier, and initiate.
Nevermore.Initiate()
NevermoreModularScript.Parent = ReplicatedStorage