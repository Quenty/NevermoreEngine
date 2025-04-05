--!strict
--[=[
	Reimplementation of Player:GetUserThumbnailAsync but as a promise with
	retry logic.

	@class PlayerThumbnailUtils
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Promise = require("Promise")

local MAX_TRIES = 5

local PlayerThumbnailUtils = {}

--[=[
	Promises a user thumbnail with retry enabled.

	```lua
	PlayerThumbnailUtils.promiseUserThumbnail(4397833):Then(function(image)
		imageLabel.Image = image
	end)
	```
	@param userId number
	@param thumbnailType ThumbnailType?
	@param thumbnailSize ThumbnailSize?
	@return Promise<string>
]=]
function PlayerThumbnailUtils.promiseUserThumbnail(
	userId: number,
	thumbnailType: Enum.ThumbnailType?,
	thumbnailSize: Enum.ThumbnailSize?
): Promise.Promise<string>
	assert(type(userId) == "number", "Bad userId")
	thumbnailType = thumbnailType or Enum.ThumbnailType.HeadShot
	thumbnailSize = thumbnailSize or Enum.ThumbnailSize.Size100x100

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
				task.wait(0.05)
			end
		until tries >= MAX_TRIES or (not promise:IsPending())

		return reject()
	end)

	return promise
end

--[=[
	Promises a player userName with retries enabled.

	See UserServiceUtils for display name and a more up-to-date API.

	@param userId number
	@return Promise<string>
]=]
function PlayerThumbnailUtils.promiseUserName(userId: number): Promise.Promise<string>
	assert(type(userId) == "number", "Bad userId")

	local promise
	promise = Promise.spawn(function(resolve, reject)
		local tries = 0
		repeat
			tries = tries + 1
			local name
			local ok, err = pcall(function()
				name = Players:GetNameFromUserIdAsync(userId)
			end)

			-- Don't retry if we immediately error (timeout exceptions!)
			if not ok then
				return reject(err)
			end

			if type(name) == "string" then
				return resolve(name)
			else
				task.wait(0.05)
			end
		until tries >= MAX_TRIES or (not promise:IsPending())

		return reject()
	end)

	return promise
end

return PlayerThumbnailUtils
