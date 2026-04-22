--!nonstrict
--[[
	@class ObservableSortedList.story
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Maid = require("Maid")
local ObservableSortedList = require("ObservableSortedList")

return function(_target)
	local maid = Maid.new()

	local observableSortedList = maid:Add(ObservableSortedList.new())

	maid:GiveTask(observableSortedList:ObserveAtIndex(-1):Subscribe(function(entry)
		print("stack entry", entry)
	end))

	observableSortedList:Add("A", 0)
	local removeB = observableSortedList:Add("B", 1)

	task.defer(function()
		removeB()
	end)

	return function()
		maid:DoCleaning()
	end
end
