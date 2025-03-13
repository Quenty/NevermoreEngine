--[=[
	Utility functions involving badges on Roblox
	@class BadgeUtils
]=]

local BadgeService = game:GetService("BadgeService")

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")

local BadgeUtils = {}

--[=[
	@interface BadgeInfoDictionary
	.Name string -- The name of the badge.
	.Description string -- The description of the badge.
	.IconImageId int64 -- The asset ID of the image for the badge.
	.IsEnabled bool -- Indicates whether the badge is available to be awarded.
	@within BadgeUtils
]=]

--[=[
	Tries to reward a player to a badge inside of a promise.

	@server
	@param player Player
	@param badgeId number
	@return Promise
]=]
function BadgeUtils.promiseAwardBadge(player: Player, badgeId: number)
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

--[=[
	Gets the badge info for the given badgeId.

	@param badgeId number
	@return Promise<BadgeInfoDictionary>
]=]
function BadgeUtils.promiseBadgeInfo(badgeId: number)
	assert(type(badgeId) == "number", "Bad badgeId")

	return Promise.spawn(function(resolve, reject)
		local data
		local ok, err = pcall(function()
			data = BadgeService:GetBadgeInfoAsync(badgeId)
		end)

		if not ok then
			return reject(err)
		end
		if type(data) ~= "table" then
			return reject("Failed to get a table of data of badgeInfo")
		end

		return resolve(data)
	end)
end

--[=[
	Returns true if the uesr has the badge

	@param userId number
	@param badgeId number
	@return Promise<BadgeInfoDictionary>
]=]
function BadgeUtils.promiseUserHasBadge(userId: number, badgeId: number)
	assert(type(userId) == "number", "Bad userId")
	assert(type(badgeId) == "number", "Bad badgeId")

	return Promise.spawn(function(resolve, reject)
		local result
		local ok, err = pcall(function()
			result = BadgeService:UserHasBadgeAsync(userId, badgeId)
		end)

		if not ok then
			return reject(err)
		end
		if type(result) ~= "boolean" then
			return reject("Failed to get a boolean from UserHasBadgeAsync")
		end

		return resolve(result)
	end)
end

return BadgeUtils