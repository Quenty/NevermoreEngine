local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local Signal = LoadCustomLibrary("Signal")

-- Intent: Acts as a list, but with signals that fire on addition

local SignaledList = {}

local mt = {
	__newindex = function(self, Index, Value)
		local OldValue = self.__list[Index]
		if OldValue ~= Value then
			self.__list[Index] = Value
			
			self.Changed:fire(Index, Value, OldValue)
		end
	end;
	__index = function(self, Index)
		if Index == "List" then
			return self.__list
		elseif SignaledList[Index] then
			return SignaledList[Index]
		else
			return self.__list[Index]
		end
	end;
}

function SignaledList.new()
	return setmetatable({
		__list = {};
		Changed = Signal.new(); -- :fire(Index, Value, OldValue)
	}, mt)
end



--[[
-- Iterater?
function SignaledList:Iterate()
	local Index, Value = next(self.__list)

	return function(Index, Value)
		Index, Value = next(self.__list, Index)
		return Index, Value
	end
end--]]


return SignaledList