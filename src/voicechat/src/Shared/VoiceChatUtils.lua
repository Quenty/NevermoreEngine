--!strict
--[=[
	@class VoiceChatUtils
]=]

local require = require(script.Parent.loader).load(script)

local VoiceChatService = game:GetService("VoiceChatService")

local Promise = require("Promise")

local VoiceChatUtils = {}

--[=[
	Reports whether voice chat is enabled

	@param player Player
	@return Promise<boolean>
]=]
function VoiceChatUtils.promiseIsVoiceEnabledForPlayer(player: Player): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return VoiceChatUtils.promiseIsVoiceEnabledForUserId(player.UserId)
end

--[=[
	Wraps whether voice chat is enabled

	@param userId number
	@return Promise<boolean>
]=]
function VoiceChatUtils.promiseIsVoiceEnabledForUserId(userId: number): Promise.Promise<boolean>
	assert(type(userId) == "number", "Bad userId")

	return Promise.spawn(function(resolve, reject)
		local result
		local ok, err = pcall(function()
			result = VoiceChatService:IsVoiceEnabledForUserIdAsync(userId)
		end)

		if not ok then
			warn(err)
			return reject(err)
		end
		if type(result) ~= "boolean" then
			return reject("Result was not a boolean")
		end

		return resolve(result)
	end)
end

return VoiceChatUtils
