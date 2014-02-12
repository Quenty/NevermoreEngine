--[[Maid
Manages the cleaning of events and other things.
 
API:
	HireMaid()                        Returns a new Maid object.
 
	Maid[key] = (function)            Adds a task to perform when cleaning up.
	Maid[key] = (event connection)    Manages an event connection. Anything that isn't a function is assumed to be this.
	Maid[key] = nil                   Removes a named task. If the task is an event, it is disconnected.
 
	Maid:GiveTask(task)               Same as above, but uses an incremented number as a key.
	Maid:DoCleaning()                 Disconnects all managed events and performs all clean-up tasks.
]]
 
local index = {
	GiveTask = function(self,task)
		local n = #self.Tasks+1
		self.Tasks[n] = task
		return n
	end;
	DoCleaning = function(self)
		local tasks = self.Tasks
		for name,task in pairs(tasks) do
			if type(task) == 'function' then
				task()
			else
				task:disconnect()
			end
			tasks[name] = nil
		end
		-- self.Tasks = {}
	end;
};
local mt = {
	__index = function(self,k)
		if index[k] then
			return index[k]
		else
			return self.Tasks[k]
		end
	end;
	__newindex = function(self,k,v)
		local tasks = self.Tasks
		if v == nil then
			-- disconnect if the task is an event
			if type(tasks[k]) ~= 'function' then
				tasks[k]:disconnect()
			end
		elseif tasks[k] then
			-- clear previous task
			self[k] = nil
		end
		tasks[k] = v
	end;
}
 
return function()
	return setmetatable({Tasks={}},mt)
end