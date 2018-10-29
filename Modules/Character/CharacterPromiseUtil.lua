--- Utility for character
-- @module CharacterPromiseUtil
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")
local fastSpawn = require("fastSpawn")

local lib = {}

function lib.PromiseRootPart(humanoid)
	local promise = Promise.new()

	if humanoid.RootPart then
		promise:Fulfill(humanoid.RootPart)
		return promise
	end

	-- humanoid:GetPropertyChangedSignal("RootPart") does not fire
	fastSpawn(function()
		local rootPart = humanoid.RootPart
		while not rootPart and promise:IsPending() do
			wait(0.05)
			rootPart = humanoid.RootPart
		end

		if rootPart and promise:IsPending() then
			promise:Fulfill(rootPart)
		end
	end)

	return promise
end

return lib