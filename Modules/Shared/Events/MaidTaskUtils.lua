---
-- @module MaidTaskUtils
-- @author Quenty

local MaidTaskUtils = {}

function MaidTaskUtils.delayed(time, task)
	assert(type(time) == "number")
	assert(task ~= nil)

	return function()
		delay(time, function()
			if type(task) == "function" then
				task()
			elseif typeof(task) == "RBXScriptConnection" then
				task:Disconnect()
			elseif task.Destroy then
				task:Destroy()
			end
		end)
	end
end

return MaidTaskUtils