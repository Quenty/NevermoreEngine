--[=[
	Provides utilities for working with Roblox's streaming system
	@class StreamingUtils
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")

local StreamingUtils = {}

--[=[
	Promises to stream the area around the player at the given position.
	@param player Player
	@param position Vector3
	@param timeOut number? -- Optional
	@return Promise
]=]
function StreamingUtils.promiseStreamAround(player, position, timeOut)
	assert(typeof(player) == "Instance", "Bad player")
	assert(typeof(position) == "Vector3", "Bad position")
	assert(type(timeOut) == "number" or timeOut == nil, "Bad timeOut")

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