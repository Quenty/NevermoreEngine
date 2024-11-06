--[[
	@class ObservableSortedList.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local ObservableSortedList = require("ObservableSortedList")

return function(_target)
	local maid = Maid.new()

	print("----")

	task.spawn(function()
		local observableSortedList = maid:Add(ObservableSortedList.new())

		local toRemove = {}

		local function add(number)
			table.insert(toRemove, observableSortedList:Add(tostring(number), number))
		end

		-- local random = Random.new(5000)
		-- for i=1, 10 do
		-- 	add(random:NextNumber())
		-- end

		local random = Random.new()
		for _i=1, 10 do
			add(math.floor(100*random:NextNumber()))
		end

		for index, node in observableSortedList._root:IterateNodesRange(3, 7) do
			print(index, node:GetIndex())
		end

		observableSortedList:PrintDebug()

		for _, item in toRemove do
			item()
		end

		-- observableSortedList:PrintDebug()
		observableSortedList:Destroy()
	end)

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

		-- print(observableSortedList:GetList())

	return function()
		maid:DoCleaning()
	end
end