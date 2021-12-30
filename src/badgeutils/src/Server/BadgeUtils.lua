--[=[
	Utility functions involving badges on Roblox
	@class BadgeUtils
]=]

local BadgeService = game:GetService("BadgeService")

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")

local BadgeUtils = {}

--[=[
	Tries to reward a player to a badge inside of a promise.

	@param player Player
	@param badgeId number
	@return Promise
]=]
function BadgeUtils.promiseAwardBadge(player, badgeId)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(type(badgeId) == "number", "Bad badgeId")

	return Promise.spawn(function(resolve, reject)
		local ok, err = pcall(function()
			BadgeService:AwardBadge(player.UserId, badgeId)
		end)

		if not ok then
			return reject(err)
		end

		return resolve(true)
	end)
end

return BadgeUtils