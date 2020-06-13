--- Utility functions for filtering text
-- @module TextFilterUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local TextService = game:GetService("TextService")

local Promise = require("Promise")

local TextFilterUtils = {}

function TextFilterUtils.getNonChatStringForBroadcastAsync(str, fromUserId, textContext)
	assert(type(str) == "string")
	assert(type(fromUserId) == "number")
	assert(typeof(textContext) == "EnumItem")

	local text = nil
	local ok, err = pcall(function()
		local result = TextService:FilterStringAsync(str, fromUserId, textContext)
		if not result then
			error("No TextFilterResult")
		end

		text = result:GetNonChatStringForBroadcastAsync()
	end)

	if not ok then
		return false, err
	end

	return text
end

function TextFilterUtils.promiseNonChatStringForBroadcast(str, fromUserId, textContext)
	assert(type(str) == "string")
	assert(type(fromUserId) == "number")
	assert(typeof(textContext) == "EnumItem")

	local promise = Promise.spawn(function(resolve, reject)
		local text, err = TextFilterUtils.getNonChatStringForBroadcastAsync(str, fromUserId, textContext)
		if not text then
			return reject(err or "Pcall failed")
		end
		if not text then
			return reject("No text")
		end

		resolve(text)
	end)

	return promise
end

return TextFilterUtils