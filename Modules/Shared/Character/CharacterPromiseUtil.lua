--- Utility for Roblox character objects that involve promises.
-- @see Promise
-- @module CharacterPromiseUtil
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")
local fastSpawn = require("fastSpawn")

local lib = {}

--- Given a humanoid creates a promise that will resolve once the `Humanoid.RootPart` property
-- resolves properly.
-- @param humanoid The humanoid to resolve for the root part
function lib.PromiseRootPart(humanoid)
	local promise = Promise.new()

	if humanoid.RootPart then
		promise:Resolve(humanoid.RootPart)
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
			promise:Resolve(rootPart)
		end
	end)

	return promise
end

return lib