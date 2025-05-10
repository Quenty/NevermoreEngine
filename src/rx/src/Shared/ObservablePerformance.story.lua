--[[
	@class ObservablePerformance.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Observable = require("Observable")

return function(_target)
	local startTime = tick()

	for _ = 1, 1000000 do
		local observable = Observable.new(function(sub)
			sub:Fire()
		end)

		local sub = observable:Subscribe(function()
			-- nooopt
		end)

		sub:Destroy()
	end

	print((tick() - startTime) * 1000 .. " ms for 1,000,000")

	return function() end
end
