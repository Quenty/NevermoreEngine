---
-- @module MaidTaskUtils
-- @author Quenty

local MaidTaskUtils = {}

function MaidTaskUtils.isValidTask(task)
	return type(task) == "function"
		or typeof(task) == "RBXScriptConnection"
		or type(task) == "table" and type(task.Destroy) == "function"
end

function MaidTaskUtils.doTask(task)
	if type(task) == "function" then
		task()
	elseif typeof(task) == "RBXScriptConnection" then
		task:Disconnect()
	elseif type(task) == "table" and type(task.Destroy) == "function" then
		task:Destroy()
	else
		error("Bad task")
	end
end

function MaidTaskUtils.delayed(time, task)
	assert(type(time) == "number")
	assert(task ~= nil)

	return function()
		delay(time, function()
			MaidTaskUtils.doTask(task)
		end)
	end
end

return MaidTaskUtils