--[[
	@class ObservableSortedList.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local ObservableSortedList = require("ObservableSortedList")

return function(target)
	local maid = Maid.new()

	local observableSortedList = maid:Add(ObservableSortedList.new())

	local function add(number)
		observableSortedList:Add(tostring(number), number)
	end

	for i=1, 10 do
		add(math.random())
	end

	-- for i=1, 10 do
	-- 	add(-i)
	-- 	add(i)
	-- end

	-- add(2)
	-- add(1)
	-- add(3)
	-- add(4)
	-- add(5)
	-- add(0)

	print(observableSortedList:GetList())
	observableSortedList:Destroy()

	return function()
		maid:DoCleaning()
	end
end