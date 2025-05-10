--!strict
--[=[
	Utility for Roblox character objects that involve promises.
	@class CharacterPromiseUtils
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Promise = require("Promise")

local CharacterPromiseUtils = {}

--[=[
	Returns a promise that will resolve once a character exists.

	@param player Player
	@return Promise<Model>
]=]
function CharacterPromiseUtils.promiseCharacter(player: Player): Promise.Promise<Model>
	assert(typeof(player) == "Instance", "Bad player")

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

return CharacterPromiseUtils
