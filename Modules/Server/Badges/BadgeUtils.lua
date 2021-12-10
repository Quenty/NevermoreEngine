---
-- @module BadgeUtils
-- @author Quenty

local BadgeService = game:GetService("BadgeService")

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

local BadgeUtils = {}

function BadgeUtils.promiseAwardBadge(player, badgeId)
	assert(typeof(player) == "Instance" and player:IsA("Player"))
	assert(type(badgeId) == "number")

	return Promise.defer(function(resolve, reject)
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