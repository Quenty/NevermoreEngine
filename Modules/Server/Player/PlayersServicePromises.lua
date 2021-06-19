--- Utility methods for async methods in Players service
-- @module PlayersServicePromises.lua

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")

local Promise = require("Promise")

local PlayersServicePromises = {}

function PlayersServicePromises.promiseUserIdFromName(name)
	assert(type(name) == "string")

	return Promise.defer(function(resolve, reject)
		local userId
		local ok, err = pcall(function()
			userId = Players:GetUserIdFromNameAsync(name)
		end)

		if not ok then
			return reject(err)
		end

		if type(userId) ~= "number" then
			return reject("UserId returned was not a number")
		end

		resolve(userId)
	end)
end

return PlayersServicePromises