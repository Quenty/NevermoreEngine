--!strict
--[=[
	Utility methods for async methods in Players service
	@class PlayersServicePromises
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Promise = require("Promise")

local PlayersServicePromises = {}

--[=[
	Promises the userId from a given name.
	@param name string
	@return Promise<UserId>
]=]
function PlayersServicePromises.promiseUserIdFromName(name: string): Promise.Promise<number>
	assert(type(name) == "string", "Bad name")

	return Promise.spawn(function(resolve, reject)
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

		return resolve(userId)
	end)
end

return PlayersServicePromises