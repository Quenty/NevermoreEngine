--- To work like value objects in ROBLOX and track a single item,
-- with `.Changed` events
-- @classmod ValueObject


local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local Signal = LoadCustomLibrary("Signal")


local ValueObject = {}
ValueObject.ClassName = "ValueObject"

function ValueObject.new()
	local self = setmetatable({}, ValueObject)
	
	--- The value of the ValueObject
	-- @field Value 

	--- Event fires when the value's object value change
	-- @signal Changed
	-- @param NewValue The new value
	-- @param OldValue The old value
	self.Changed = Signal.new() -- :Fire(NewValue, OldValue)
	
	return self
end



function ValueObject:__index(Index)
	if Index == "Value" then
		return self._Value
	elseif Index == "_Value" then
		return nil -- Edge case.
	elseif ValueObject[Index] then
		return ValueObject[Index]
	else
		error("'" .. tostring(Index) .. "' is not a member of ValueObject")
	end
end

function ValueObject:__newindex(Index, Value)
	if Index == "Value" then
		if self.Value ~= Value then
			local Old = self.Value
			self._Value = Value
			self.Changed:fire(Value, Old)
		end
	elseif Index == "_Value" then
		rawset(self, Index, Value)
	elseif Index == "Changed" then
		rawset(self, Index, Value)
	else
		error("'" .. tostring(Index) .. "' is not a member of ValueObject")
	end
end

return ValueObject