--[[
	@class Maid.story
]]

local Maid = require(script.Parent.Maid)

return function()
	local maid = Maid.new()

	local thread = maid:Add(task.spawn(function()
		while true do
			task.wait(0.1) -- In the spawn scenario this yields control back to the main thread, adding the task.
			error("Task is not cancelled because of change")
		end
	end))

	return function()
		maid:DoCleaning()
		task.cancel(thread)
	end
end
