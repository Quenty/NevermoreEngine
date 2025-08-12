--[[
	@class Signal.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Signal = require("Signal")

return function(_target)
	local signal = Signal.new()

	local connections = {}
	local disconnect = { [5] = true, [1] = true }
	local connect = 5
	local fireCount = 0
	for i = 1, 5 do
		connections[i] = signal:Connect(function()
			fireCount += 1

			if i == connect then
				signal:Connect(function()
					fireCount += 1
				end)
			end

			if disconnect[i] then
				connections[i]:Disconnect()
			end
		end)
	end

	assert(signal:GetConnectionCount() == 5, "Connection count should be 5")
	assert(fireCount == 0, "Bad fireCount")

	signal:Fire()

	assert(signal:GetConnectionCount() == 4, "Connection count should be 4")
	assert(fireCount == 5, "Bad fireCount")
	print("Done")

	return function()
		signal:Destroy()
	end
end
