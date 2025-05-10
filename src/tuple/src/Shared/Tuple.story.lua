--[[
	@class Tuple.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Tuple = require("Tuple")

return function(_target: Frame)
	local a = Tuple.new(1, 2, 3)
	local b = Tuple.new(1, 2, 3)
	local c = Tuple.new(3, 4, "d")

	assert(tostring(a) == "1, 2, 3", "Bad a")
	assert(tostring(c) == "3, 4, d", "Bad c")
	assert(#a == 3, "Bad a")
	assert(a == b, "a == b")
	assert(b == b, "b == b")
	assert(a ~= c, "b == b")

	-- Addition
	assert(tostring(a + c) == "1, 2, 3, 3, 4, d", "Bad addition")
	assert(#a:ToArray() == 3, "Bad toArray")

	local lookupTable = {}
	lookupTable[a] = true

	assert(lookupTable[b] == false, "Lookup should not be equivalent")

	return function() end
end
