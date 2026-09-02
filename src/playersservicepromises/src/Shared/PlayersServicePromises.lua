--!strict
--[=[
	Utility methods for async methods in Players service
	@class PlayersServicePromises
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local PlayerMock = require("PlayerMock")
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
		-- The mocked `Players` service is DataModel-wide, so any mock is an equally good handle onto
		-- it, and it answers nil for a name no mock carries.
		local mocks = PlayerMock.getMocks()
		if #mocks > 0 then
			local mockedUserId = PlayerMock.callMethod(mocks[1], "Players.GetUserIdFromNameAsync", name)
			if mockedUserId ~= nil then
				return resolve(mockedUserId)
			end
		end

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
