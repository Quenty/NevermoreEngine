--[[
	@class ObservableSortedList.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local ObservableSortedList = require("ObservableSortedList")

return function(_target)
	local maid = Maid.new()

	local function test(n, label, sortedList, getElement)
		local function add(number)
			sortedList:Add(tostring(number), number)
		end

		local startTime = os.clock()
		for i = 1, n do
			add(getElement(i))
		end

		print(string.format("%25s %0.2f ms", label .. " construction", (os.clock() - startTime) * 1000))
	end

	local function cleanup(label, sortedList)
		local startTime = os.clock()

		sortedList:Destroy()

		print(string.format("%25s %0.2f ms", label .. " destruction", (os.clock() - startTime) * 1000))
	end

	local function getRandomElement()
		return math.random()
	end

	local function inOrder(i)
		return i
	end

	local function same()
		return 0
	end

	local function runTest(label, n, getElement)
		local observableSortedList = maid:Add(ObservableSortedList.new())

		print(string.format("%25s n = %d", label, n))
		print(string.format("%25s %8s", string.rep("-", 25), string.rep("-", 10)))

		test(n, "new impl", observableSortedList, getElement)
		cleanup("new impl", observableSortedList)

		print("\n")
	end

	local n = 1000
	runTest("test random_order", n, getRandomElement)
	runTest("test in_order", n, inOrder)
	runTest("same", n, same)

	return function()
		maid:DoCleaning()
	end
end
