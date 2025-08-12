--[[
	@class ValueObject.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local ValueObject = require("ValueObject")

return function()
	local maid = Maid.new()

	local valueObject = maid:Add(ValueObject.new())

	local fireCount = 0
	local conn = valueObject:Observe():Subscribe(function()
		fireCount += 1
	end)

	assert(fireCount == 1, "fireCount should be 1")

	valueObject.Value = {}

	assert(fireCount == 2, "fireCount should be 2")

	maid:GiveTask(valueObject:Observe():Subscribe(function()
		fireCount += 1
	end))

	assert(fireCount == 3, "fireCount should be 3")
	valueObject.Value = {}
	assert(fireCount == 5, "fireCount should be 5")

	conn:Disconnect()

	assert(fireCount == 5, "fireCount should be 5")

	valueObject.Value = {}

	assert(fireCount == 6, "fireCount should be 5")

	print("Done")

	return function()
		maid:DoCleaning()
	end
end
