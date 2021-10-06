--- Utility functions involving badges on Roblox
-- @module BadgeUtils
-- @author Quenty

local BadgeService = game:GetService("BadgeService")

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")

local BadgeUtils = {}

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