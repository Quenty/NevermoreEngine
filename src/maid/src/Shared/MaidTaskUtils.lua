---
-- @module MaidTaskUtils
-- @author Quenty

local MaidTaskUtils = {}

function MaidTaskUtils.isValidTask(job)
	return type(job) == "function"
		or typeof(job) == "RBXScriptConnection"
		or type(job) == "table" and type(job.Destroy) == "function"
end

function MaidTaskUtils.doTask(job)
	if type(job) == "function" then
		job()
	elseif typeof(job) == "RBXScriptConnection" then
		job:Disconnect()
	elseif type(job) == "table" and type(job.Destroy) == "function" then
		job:Destroy()
	else
		error("Bad job")
	end
end

function MaidTaskUtils.delayed(time, job)
	assert(type(time) == "number", "Bad time")
	assert(MaidTaskUtils.isValidTask(job), "Bad job")

	return function()
		task.delay(time, function()
			MaidTaskUtils.doTask(job)
		end)
	end
end

return MaidTaskUtils