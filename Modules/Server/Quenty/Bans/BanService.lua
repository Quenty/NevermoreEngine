--- Hits Quenty.org for bans
-- @module BanService
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local HttpPromise = require("HttpPromise")
local UserModStatus = require("UserModStatus")
local Promise = require("Promise")

local BanService = {}

function BanService:IsBannedAsync(userId)
	local result, err = self:_getUserStatusAsync(userId)
	if result then
		return result.banned, result
	else
		warn(("[BanService] - Unable to decoded Json result, %q"):format(tostring(err)))
		return false, nil
	end
end

function BanService:PromiseUserModStatus(userId)
	return HttpPromise.json(string.format("https://quenty.org/banned/%d/status", userId))
		:Then(function(data)
			if data.err then
				return Promise.rejected(data.err)
			else
				return UserModStatus.new(data)
			end
		end)
end


return BanService