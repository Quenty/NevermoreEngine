---	Manages the cleaning of events and other things. 
-- Useful for encapsulating state and make deconstructors easy
-- @classmod Maid
-- @see Signal

local Maid = {}
Maid.ClassName = "Maid"

--- Returns a new Maid object
function Maid.new()
	local self = {}
	
	self.Tasks = {}
	
	return setmetatable(self, Maid)
end
Maid.MakeMaid = Maid.new

--- Returns Maid[key] if not part of Maid metatable
-- @return Maid[key] value
function Maid:__index(Index)
	if Maid[Index] then
		return Maid[Index]
	else
		return self.Tasks[Index]
	end
end

--- Add a task to clean up
-- @usage
-- Maid[key] = (function)            Adds a task to perform
-- Maid[key] = (event connection)    Manages an event connection
-- Maid[key] = (Maid)                Maids can act as an event connection, allowing a Maid to have other maids to clean up.
-- Maid[key] = (Object)              Maids can cleanup objects with a `Destroy` method
-- Maid[key] = nil                   Removes a named task. If the task is an event, it is disconnected. If it is an object, it is destroyed.
function Maid:__newindex(Index, NewTask)
	if Maid[Index] ~= nil then
		error(("'%s' is reserved"):format(tostring(Index)), 2)
	end
	
	local Tasks = self.Tasks
	local OldTask = Tasks[Index]
	Tasks[Index] = NewTask

	if OldTask then
		if type(OldTask) == "function" then
			OldTask()
		elseif typeof(OldTask) == "RBXScriptConnection" then
			OldTask:disconnect()
		elseif OldTask.Destroy then
			OldTask:Destroy()
		end
	end
end

--- Same as indexing, but uses an incremented number as a key.
-- @param Task An item to clean
-- @return int TaskId
function Maid:GiveTask(Task)
	local TaskId = #self.Tasks+1
	self[TaskId] = Task
	return TaskId
end

--- Cleans up all tasks.
-- @alias Destroy
function Maid:DoCleaning()
	local Tasks = self.Tasks

	-- Disconnect all events first as we know this is safe
	for Index, Task in pairs(Tasks) do
		if typeof(Task) == "RBXScriptConnection" then
			Tasks[Index] = nil
			Task:disconnect()
		end
	end

	-- Clear out tasks table completely, even if clean up tasks add more tasks to the maid
	local Index, Task = next(Tasks)
	while Task ~= nil do
		Tasks[Index] = nil
		if type(Task) == "function" then
			Task()
		elseif typeof(Task) == "RBXScriptConnection" then
			Task:disconnect()
		elseif Task.Destroy then
			Task:Destroy()
		end
		Index, Task = next(Tasks)
	end
end

--- Alias for DoCleaning()
-- @function Destroy 
Maid.Destroy = Maid.DoCleaning

return Maid