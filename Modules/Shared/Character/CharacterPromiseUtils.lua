--- Utility for Roblox character objects that involve promises.
-- @see Promise
-- @module CharacterPromiseUtil

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")
local fastSpawn = require("fastSpawn")
local Maid = require("Maid")

local CharacterPromiseUtil = {}

--- Given a humanoid creates a promise that will resolve once the `Humanoid.RootPart` property
-- resolves properly.
-- @param humanoid The humanoid to resolve for the root part
function CharacterPromiseUtil.promiseRootPart(humanoid)
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

function CharacterPromiseUtil.promiseCharacter(player)
	assert(typeof(player) == "Instance")

	local promise = Promise.new()

	if player.Character then
		promise:Resolve(player.Character)
		return promise
	end

	local maid = Maid.new()

	maid:GiveTask(player.CharacterAdded:Connect(function(character)
		promise:Resolve(character)
	end))

	promise:Finally(function()
		maid:DoCleaning()
	end)

	return promise

end

return CharacterPromiseUtil

