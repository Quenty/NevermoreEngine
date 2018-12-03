---
-- @module TextFilterUtil
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local TextService = game:GetService("TextService")

local Promise = require("Promise")

local TextFilterUtil = {}

function TextFilterUtil.PromiseNonChatStringForBroadcast(string, userId)
	assert(type(string) == "string")
	assert(type(userId) == "number")

	local promise = Promise.new(function(resolve, reject)
		local text = nil
		local ok, err = pcall(function()
			local result = TextService:FilterStringAsync(string, userId)
			if not result then
				return reject("No TextFilterResult")
			end

			text = result:GetNonChatStringForBroadcastAsync()
		end)
		if not ok then
			return reject(err or "Pcall failed")
		end
		if not text then
			return reject("No text")
		end

		resolve(text)
	end)

	return promise
end

return TextFilterUtil