--[=[
	Utility methods involving maids and tasks.
	@class MaidTaskUtils
]=]

--[=[
	An object that can have the method :Destroy() called on it
	@type Destructable Instance | { Destroy: function }
	@within MaidTaskUtils
]=]
export type Destructable = any

--[=[
	An object that can be cleaned up
	@type MaidTask function | thread | Destructable | RBXScriptConnection
	@within MaidTaskUtils
]=]
export type MaidTask = (() -> ()) | Instance | thread | Destructable | RBXScriptConnection | nil

local MaidTaskUtils = {}

--[=[
	Returns whether a task is a valid job.

	@param job any
	@return boolean
]=]
function MaidTaskUtils.isValidTask(job: any): boolean
	local jobType = typeof(job)
	return jobType == "function"
		or jobType == "thread"
		or jobType == "RBXScriptConnection"
		or jobType == "Instance"
		or (jobType == "table" and type(job.Destroy) == "function")
end

--[=[
	Executes the task as requested.

	@param job MaidTask -- Task to execute
]=]
function MaidTaskUtils.doTask(job: MaidTask)
	if typeof(job) == "function" then
		(job :: any)()
	elseif typeof(job) == "table" then
		if type(job.Destroy) == "function" then
			job:Destroy()
		end
	elseif typeof(job) == "Instance" then
		job:Destroy()
	elseif typeof(job) == "thread" then
		local cancelled
		if coroutine.running() ~= job then
			cancelled = pcall(function()
				task.cancel(job)
			end)
		end

		if not cancelled then
			task.defer(function()
				task.cancel(job)
			end)
		end
	elseif typeof(job) == "RBXScriptConnection" then
		job:Disconnect()
	else
		error(string.format("[MaidTaskUtils.doTask] - Bad job of type %q", typeof(job)))
	end
end

--[=[
	Executes the task delayed after some time.

	```lua
	-- delays cleanup by 5 seconds
	maid:GiveTask(MaidTaskUtils.delayed(5, gui))
	```

	@param time number -- Time in seconds
	@param job MaidTask -- Job to delay execution
	@return () -> () -- function that will execute the job delayed
]=]
function MaidTaskUtils.delayed(time: number, job: MaidTask)
	assert(type(time) == "number", "Bad time")
	assert(MaidTaskUtils.isValidTask(job), "Bad job")

	return function()
		task.delay(time, function()
			MaidTaskUtils.doTask(job)
		end)
	end
end

return MaidTaskUtils
