--[=[
	Manages the cleaning of events and other things. Useful for
	encapsulating state and make deconstructors easy.

	See the [Five Powerful Code Patterns talk](https://developer.roblox.com/en-us/videos/5-powerful-code-patterns-behind-top-roblox-games)
	for a more in-depth look at Maids in top games.

	```lua
	local maid = Maid.new()

	maid:GiveTask(function()
		print("Cleaning up")
	end)

	maid:GiveTask(workspace.ChildAdded:Connect(print))

	-- Disconnects all events, and executes all functions
	maid:DoCleaning()
	```

	@class Maid
]=]
-- luacheck: pop

local Maid = {}
Maid.ClassName = "Maid"

--[=[
	Constructs a new Maid object

	```lua
	local maid = Maid.new()
	```

	@return Maid
]=]
function Maid.new()
	return setmetatable({
		_tasks = {}
	}, Maid)
end

--[=[
	Returns true if the class is a maid, and false otherwise.

	```lua
	print(Maid.isMaid(Maid.new())) --> true
	print(Maid.isMaid(nil)) --> false
	```

	@param value any
	@return boolean
]=]
function Maid.isMaid(value)
	return type(value) == "table" and value.ClassName == "Maid"
end

--[=[
	Returns Maid[key] if not part of Maid metatable

	```lua
	local maid = Maid.new()
	maid._current = Instance.new("Part")
	print(maid._current) --> Part

	maid._current = nil
	print(maid._current) --> nil
	```

	@param index any
	@return MaidTask
]=]
function Maid:__index(index)
	if Maid[index] then
		return Maid[index]
	else
		return self._tasks[index]
	end
end

--[=[
	Add a task to clean up. Tasks given to a maid will be cleaned when
	maid[index] is set to a different value.

	Task cleanup is such that if the task is an event, it is disconnected.
	If it is an object, it is destroyed.

	```
	Maid[key] = (function)         Adds a task to perform
	Maid[key] = (event connection) Manages an event connection
	Maid[key] = (thread)           Manages a thread
	Maid[key] = (Maid)             Maids can act as an event connection, allowing a Maid to have other maids to clean up.
	Maid[key] = (Object)           Maids can cleanup objects with a `Destroy` method
	Maid[key] = nil                Removes a named task.
	```

	@param index any
	@param newTask MaidTask
]=]
function Maid:__newindex(index, newTask)
	if Maid[index] ~= nil then
		error(("Cannot use '%s' as a Maid key"):format(tostring(index)), 2)
	end

	local tasks = self._tasks
	local oldTask = tasks[index]

	if oldTask == newTask then
		return
	end

	tasks[index] = newTask

	if oldTask then
		if type(oldTask) == "function" then
			oldTask()
		elseif type(oldTask) == "thread" then
			local cancelled
			if coroutine.running() ~= oldTask then
				cancelled = pcall(function()
					task.cancel(oldTask)
				end)
			end

			if not cancelled then
				task.defer(function()
					task.cancel(oldTask)
				end)
			end
		elseif typeof(oldTask) == "RBXScriptConnection" then
			oldTask:Disconnect()
		elseif oldTask.Destroy then
			oldTask:Destroy()
		end
	end
end

--[=[
	Gives a task to the maid for cleanup and returns the resulting value

	@param task MaidTask -- An item to clean
	@return MaidTask
]=]
function Maid:Add(task)
	if not task then
		error("Task cannot be false or nil", 2)
	end

	self[#self._tasks+1] = task

	if type(task) == "table" and (not task.Destroy) then
		warn("[Maid.GiveTask] - Gave table task without .Destroy\n\n" .. debug.traceback())
	end

	return task
end

--[=[
	Gives a task to the maid for cleanup, but uses an incremented number as a key.

	@param task MaidTask -- An item to clean
	@return number -- taskId
]=]
function Maid:GiveTask(task)
	if not task then
		error("Task cannot be false or nil", 2)
	end

	local taskId = #self._tasks+1
	self[taskId] = task

	if type(task) == "table" and (not task.Destroy) then
		warn("[Maid.GiveTask] - Gave table task without .Destroy\n\n" .. debug.traceback())
	end

	return taskId
end

--[=[
	Gives a promise to the maid for clean.

	@param promise Promise<T>
	@return Promise<T>
]=]
function Maid:GivePromise(promise)
	if not promise:IsPending() then
		return promise
	end

	local newPromise = promise.resolved(promise)
	local id = self:GiveTask(newPromise)

	-- Ensure GC
	newPromise:Finally(function()
		self[id] = nil
	end)

	return newPromise
end

--[=[
	Cleans up all tasks and removes them as entries from the Maid.

	:::note
	Signals that are already connected are always disconnected first. After that
	any signals added during a cleaning phase will be disconnected at random times.
	:::

	:::tip
	DoCleaning() may be recursively invoked. This allows the you to ensure that
	tasks or other tasks. Each task will be executed once.

	However, adding tasks while cleaning is not generally a good idea, as if you add a
	function that adds itself, this will loop indefinitely.
	:::
]=]
function Maid:DoCleaning()
	local tasks = self._tasks

	-- Disconnect all events first as we know this is safe
	for index, job in pairs(tasks) do
		if typeof(job) == "RBXScriptConnection" then
			tasks[index] = nil
			job:Disconnect()
		end
	end

	-- Clear out tasks table completely, even if clean up tasks add more tasks to the maid
	local index, job = next(tasks)
	while job ~= nil do
		tasks[index] = nil
		if type(job) == "function" then
			job()
		elseif type(job) == "thread" then
			local cancelled
			if coroutine.running() ~= job then
				cancelled = pcall(function()
					task.cancel(job)
				end)
			end

			if not cancelled then
				local toCancel = job
				task.defer(function()
					task.cancel(toCancel)
				end)
			end
		elseif typeof(job) == "RBXScriptConnection" then
			job:Disconnect()
		elseif job.Destroy then
			job:Destroy()
		end
		index, job = next(tasks)
	end
end

--[=[
	Alias for [Maid.DoCleaning()](/api/Maid#DoCleaning)

	@function Destroy
	@within Maid
]=]
Maid.Destroy = Maid.DoCleaning

return Maid