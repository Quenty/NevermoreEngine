--!strict
--[=[
	Utility functions wrapping SocialService with promises
	@class SocialServiceUtils
]=]

local require = require(script.Parent.loader).load(script)

local SocialService = game:GetService("SocialService")

local Promise = require("Promise")
local Maid = require("Maid")

local SocialServiceUtils = {}

--[=[
	Wraps SocialService:CanSendGameInviteAsync(player)
	@param player Player
	@return Promise<boolean>
]=]
function SocialServiceUtils.promiseCanSendGameInvite(player: Player): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return Promise.spawn(function(resolve, reject)
		local canSend
		local ok, err = pcall(function()
			canSend = SocialService:CanSendGameInviteAsync(player)
		end)
		if not ok then
			return reject(err)
		end

		return resolve(canSend)
	end)
end

--[=[
	Prompts the user to send an in-game invite and resolves once the prompt is closed.

	@param player Player
	@param options ExperienceInviteOptions?
	@return Promise
]=]
function SocialServiceUtils.promisePromptGameInvite(player: Player, options: ExperienceInviteOptions?): Promise.Promise<()>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(not options or (typeof(options) == "Instance" and options:IsA("ExperienceInviteOptions")), "Bad options")

	local maid = Maid.new()

	return Promise.spawn(function(resolve, reject)
		maid:GiveTask(SocialService.GameInvitePromptClosed:Connect(function(closingPlayer)
			if (closingPlayer :: any) == player then
				resolve(player)
			end
		end))

		local ok, err = pcall(function()
			SocialService:PromptGameInvite(player, options)
		end)
		if not ok then
			return reject(err)
		end

		-- TODO: Maybe timeout here?
		return
	end):Tap(function()
		maid:DoCleaning()
	end, function()
		maid:DoCleaning()
	end)
end

return SocialServiceUtils
