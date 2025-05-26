--!strict
--[=[
	Provides utilities for working with Roblox's streaming system
	@class StreamingUtils
]=]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Promise = require("Promise")

local StreamingUtils = {}

--[=[
	Promises to stream the area around the player at the given position. See [Player.RequestStreamAroundAsync]. Can
	be called on both the client and the server.

	```lua
	StreamingUtils.promiseStreamAround(Players.LocalPlayer, Vector3.new(0, 10, 0), 30)
		:Then(function()
			print("Done streaming")
		end)
	```

	Returns a resolved promise if streaming is not enabled as the area is guaranteed to be streamed in already.

	:::warning
	Requesting streaming around an area is not a guarantee that the content will be present when the request completes,
	as streaming is affected by the client's network bandwidth, memory limitations, and other factors.
	:::

	@param player Player
	@param position Vector3
	@param timeOut number? -- Optional
	@return Promise
]=]
function StreamingUtils.promiseStreamAround(player: Player, position: Vector3, timeOut: number?): Promise.Promise<()>
	assert(typeof(player) == "Instance", "Bad player")
	assert(typeof(position) == "Vector3", "Bad position")
	assert(type(timeOut) == "number" or timeOut == nil, "Bad timeOut")

	-- Guaranteed to be streamed in, no need to do anything
	if not Workspace.StreamingEnabled then
		return Promise.resolved()
	end

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
