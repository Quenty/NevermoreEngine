--- Reimplementation of Player:GetUserThumbnailAsync but as a promise with
--  retry logic
-- @module PlayerThumbnails

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")

local Promise = require("Promise")

local PlayerThumbnails = {}
PlayerThumbnails.ThumbnailPollerName = "PlayerThumbnails"
PlayerThumbnails.__index = PlayerThumbnails
PlayerThumbnails.MAX_TRIES = 5

function PlayerThumbnails.new()
	local self = setmetatable({}, PlayerThumbnails)

	return self
end

function PlayerThumbnails:GetUserThumbnail(userId, thumbnailType, thumbnailSize)
	assert(userId)
	assert(thumbnailType)
	assert(thumbnailSize)

	local promise
	promise = Promise.spawn(function(resolve, reject)
		local tries = 0
		repeat
			tries = tries + 1
			local content, isReady
			local ok, err = pcall(function()
				content, isReady = Players:GetUserThumbnailAsync(userId, thumbnailType, thumbnailSize)
			end)

			-- Don't retry if we immediately error (timeout exceptions!)
			if not ok then
				return reject(err)
			end

			if isReady then
				return resolve(content)
			else
				wait(0.05)
			end
		until tries >= self.MAX_TRIES or (not promise:IsPending())
		reject()
	end)

	return promise
end


return PlayerThumbnails.new()