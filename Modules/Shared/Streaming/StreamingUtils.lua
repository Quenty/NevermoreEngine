---
-- @module StreamingUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

local StreamingUtils = {}

function StreamingUtils.promiseStreamAround(player, position, timeOut)
	assert(typeof(player) == "Instance")
	assert(typeof(position) == "Vector3")
	assert(type(timeOut) == "number" or timeOut == nil)

	return Promise.spawn(function(resolve, reject)
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