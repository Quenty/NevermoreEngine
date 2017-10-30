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
	self.IsCurrentlyCleaning = false
	
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
-- Maid[key] = (function)            Adds a task to perform when cleaning up.
-- Maid[key] = (event connection)    Manages an event connection. Anything that isn"t a function is assumed to be this.
-- Maid[key] = (Maid)                Maids can act as an event connection, allowing a Maid to have other maids to clean up.
-- Maid[key] = (Object)              Maids can cleanup objects with a `Destroy` method
-- Maid[key] = nil                   Removes a named task. If the task is an event, it is disconnected. If it is an object, it is destroyed.
function Maid:__newindex(Index, Value)
	if self.IsCurrentlyCleaning then
		error(("Already cleaning, cannot add index '%s'"):format(tostring(Index)), 2)
	elseif Maid[Index] ~= nil then
		error(("'%s' is reserved"):format(tostring(Index)), 2)
	end
	
	self.IsCurrentlyCleaning = true
	local Tasks = self.Tasks
	
	-- Disconnect if the task is an event and destroy if the task is an object
	if Tasks[Index] ~= nil and type(Tasks[Index]) ~= "function" then
		if typeof(Tasks[Index]) == "RBXScriptConnection" then
			Tasks[Index]:disconnect()
		else
			Tasks[Index]:Destroy()
		end
	end
	self.IsCurrentlyCleaning = false
	
	Tasks[Index] = Value
end

--- Same as indexing, but uses an incremented number as a key
-- @param Task An item to clean
-- @return int TaskId
function Maid:GiveTask(Task)
	if self.IsCurrentlyCleaning then
		error(("Currently cleaning, cannot give task"), 2)
	end
	
	local TaskId = #self.Tasks+1
	self[TaskId] = Task
	return TaskId
end

--- Returns true is in cleaning process
-- @return True if cleaning, false otherwise
function Maid:IsCleaning()
	return self.IsCurrentlyCleaning
end

--- Disconnects all managed events and performs all clean-up tasks
function Maid:DoCleaning()
	if self.IsCurrentlyCleaning then
		error("Already cleaning, cannot call DoCleaning()", 2)
		return
	end
	
	self.IsCurrentlyCleaning = true
	local Tasks = self.Tasks
	for Index, Task in pairs(Tasks) do
		if type(Task) == "function" then
			Task()
		elseif typeof(Task) == "RBXScriptConnection" then
			Task:disconnect()
		else
			Task:Destroy()
		end
		Tasks[Index] = nil
	end
	self.IsCurrentlyCleaning = false
end
Maid.Destroy = Maid.DoCleaning -- Allow maids to nested

return Maid