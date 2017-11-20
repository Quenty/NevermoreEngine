--[[Maid
Manages the cleaning of events and other things. 

Modified by Quenty
 
API:
	MakeMaid()                        Returns a new Maid object.
 
	Maid[key] = (function)            Adds a task to perform when cleaning up.
	Maid[key] = (event connection)    Manages an event connection. Anything that isn"t a function is assumed to be this.
	Maid[key] = (Maid)                Maids can act as an event connection, allowing a Maid to have other maids to clean up.
	Maid[key] = (Object)              Maids can cleanup objects with a `Destroy` method
	Maid[key] = nil                   Removes a named task. If the task is an event, it is disconnected. If it is an object, it is destroyed.
 
	Maid:GiveTask(task)               Same as above, but uses an incremented number as a key.
	Maid:DoCleaning()                 Disconnects all managed events and performs all clean-up tasks.
	Maid:IsCleaning()				  Returns true is in cleaning process.
	Maid:Destroy()                    Alias for DoCleaning()
]]

--- Manages the cleaning of events and other things.
local Maid = {}

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

--- Same as indexing, but uses an incremented number as a key
-- @param Task An item to clean
-- @return int TaskId
function Maid:GiveTask(Task)
	local TaskId = #self.Tasks+1
	self[TaskId] = Task
	return TaskId
end

--- Cleans up all tasks
function Maid:DoCleaning()
	local Tasks = self.Tasks

	-- Disconnect all events first as we know this is safe
	for Index, Task in pairs(Tasks) do
		Tasks[Index] = nil
		if typeof(Task) == "RBXScriptConnection" then
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
Maid.Destroy = Maid.DoCleaning -- Allow maids to nested

return Maid