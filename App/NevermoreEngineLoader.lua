--- This scripts loads Nevermore from the server.
-- It also replicates Nevermore into ReplicatedStorage for internal usage. 

-----------------------
-- UTILITY FUNCTIONS --
-----------------------

local TestService       = game:GetService('TestService')
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function WaitForChild(Parent, Name, TimeLimit)
	--- Waits for a child to appear. Not efficient, but it shouldn't have to be. Helps with debugging. 
	-- Useful when ROBLOX lags out, and doesn't replicate quickly.
	-- @param TimeLimit If given, function will return after TimeLimit, even if Child isn't found.
	-- @return The Child if found, or nil if not.

	assert(Parent ~= nil, "Parent is nil")
	assert(type(Name) == "string", "Name is not a string.")

	local Child     = Parent:FindFirstChild(Name)
	local StartTime = tick()
	local Warned    = false

	while not Child and Parent do
		wait(0)
		Child = Parent:FindFirstChild(Name)
		if not Warned and StartTime + (TimeLimit or 5) <= tick() then
			Warned = true
			warn("Infinite yield possible for WaitForChild(" .. Parent:GetFullName() .. ", " .. Name .. ")")
			if TimeLimit then
				return Parent:FindFirstChild(Name)
			end
		end
	end

	if not Parent then
		warn("Parent became nil.")
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

-- Identify the NevermoreEngine module
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