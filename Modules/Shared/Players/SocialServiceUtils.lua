---
-- @module SocialServiceUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local SocialService = game:GetService("SocialService")

local Promise = require("Promise")
local Maid = require("Maid")

local SocialServiceUtils = {}

function SocialServiceUtils.promiseCanSendGameInvite(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"))

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

function SocialServiceUtils.promisePromptGameInvite(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"))

	local maid = Maid.new()

	return Promise.spawn(function(resolve, reject)
		maid:GiveTask(SocialService.GameInvitePromptClosed:Connect(function(closingPlayer)
			if closingPlayer == player then
				resolve(player)
			end
		end))

		local ok, err = pcall(function()
			SocialService:PromptGameInvite(player)
		end)
		if not ok then
			return reject(err)
		end

		-- TODO: Maybe timeout here?
	end)
	:Tap(function()
		maid:DoCleaning()
	end, function()
		maid:DoCleaning()
	end)
end

return SocialServiceUtils