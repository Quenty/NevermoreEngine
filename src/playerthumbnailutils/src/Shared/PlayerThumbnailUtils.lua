--- Reimplementation of Player:GetUserThumbnailAsync but as a promise with
--  retry logic
-- @module PlayerThumbnailUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")

local Promise = require("Promise")

local MAX_TRIES = 5

local PlayerThumbnailUtils = {}

function PlayerThumbnailUtils.promiseUserThumbnail(userId, thumbnailType, thumbnailSize)
	assert(type(userId) == "number")
	thumbnailType = thumbnailType or Enum.ThumbnailType.HeadShot
	thumbnailSize = thumbnailSize or Enum.ThumbnailSize.Size100x100

	local promise
	promise = Promise.defer(function(resolve, reject)
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
		until tries >= MAX_TRIES or (not promise:IsPending())
		reject()
	end)

	return promise
end

return PlayerThumbnailUtils