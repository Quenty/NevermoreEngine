--!strict
--[=[
	Reimplementation of Player:GetUserThumbnailAsync but as a promise with
	retry logic.

	@class PlayerThumbnailUtils
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local PlayerMock = require("PlayerMock")
local Promise = require("Promise")

local MAX_TRIES = 5

-- What each ThumbnailType is called in an rbxthumb:// content URL, which is the shape
-- GetUserThumbnailAsync itself resolves -- so a mock's thumbnail can derive from its UserId alone.
local THUMBNAIL_TYPE_TO_RBXTHUMB_TYPE = {
	[Enum.ThumbnailType.HeadShot] = "AvatarHeadShot",
	[Enum.ThumbnailType.AvatarBust] = "AvatarBust",
	[Enum.ThumbnailType.AvatarThumbnail] = "Avatar",
}

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
	local resolvedThumbnailType: Enum.ThumbnailType = thumbnailType or Enum.ThumbnailType.HeadShot
	local resolvedThumbnailSize: Enum.ThumbnailSize = thumbnailSize or Enum.ThumbnailSize.Size100x100

	local promise
	promise = Promise.spawn(function(resolve, reject)
		if PlayerMock.getMockByUserId(userId) ~= nil then
			-- The engine call would reject a fake UserId; derive the rbxthumb content URL it
			-- would resolve for a real one.
			local width, height = string.match(resolvedThumbnailSize.Name, "^Size(%d+)x(%d+)$")
			if width == nil or height == nil then
				return reject(string.format("Failed to parse thumbnail size %q", resolvedThumbnailSize.Name))
			end

			return resolve(
				string.format(
					"rbxthumb://type=%s&id=%d&w=%s&h=%s",
					THUMBNAIL_TYPE_TO_RBXTHUMB_TYPE[resolvedThumbnailType],
					userId,
					width,
					height
				)
			)
		end

		local tries = 0
		repeat
			tries = tries + 1
			local content, isReady
			local ok, err = pcall(function()
				content, isReady = Players:GetUserThumbnailAsync(userId, resolvedThumbnailType, resolvedThumbnailSize)
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
		local mockPlayer = PlayerMock.getMockByUserId(userId)
		if mockPlayer ~= nil then
			-- Resolved from the same user-info domain UserServiceUtils reads, so the two
			-- packages' usernames can never disagree for a mock.
			return resolve(PlayerMock.readLookup(mockPlayer, "UserService.GetUserInfosByUserIdsAsync", 0).Username)
		end

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
