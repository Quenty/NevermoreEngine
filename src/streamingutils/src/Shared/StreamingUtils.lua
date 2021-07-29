--- Provides utilities for working with Roblox's streaming system
-- @module StreamingUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

local StreamingUtils = {}

function StreamingUtils.promiseStreamAround(player, position, timeOut)
	assert(typeof(player) == "Instance", "Bad player")
	assert(typeof(position) == "Vector3", "Bad position")
	assert(type(timeOut) == "number" or timeOut == nil, "Bad timeOut")

	return Promise.defer(function(resolve, reject)
		local ok, err = pcall(function()
			player:RequestStreamAroundAsync(position, timeOut)
		end)

		if not ok then
			return reject(err)
		end

		return resolve()
	end)
end

return StreamingUtils