--[=[
	To work like value objects in Roblox and track a single item,
	with `.Changed` events
	@class ValueObject
]=]

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local Maid = require("Maid")

local ValueObject = {}
ValueObject.ClassName = "ValueObject"

--[=[
	Constructs a new value object
	@param baseValue T
	@return ValueObject
]=]
function ValueObject.new(baseValue)
	local self = {}

	rawset(self, "_value", baseValue)

	self._maid = Maid.new()

	self.Changed = Signal.new() -- :Fire(newValue, oldValue, maid)
	self._maid:GiveTask(self.Changed)

	return setmetatable(self, ValueObject)
end

--[=[
	Returns whether the object is a ValueObject class
	@param value any
	@return boolean
]=]
function ValueObject.isValueObject(value)
	return type(value) == "table" and getmetatable(value) == ValueObject
end

--[=[
	Event fires when the value's object value change
	@prop Changed Signal<T> -- fires with oldValue, newValue
	@within ValueObject
]=]

--[=[
	The value of the ValueObject
	@prop Value T
	@within ValueObject
]=]
function ValueObject:__index(index)
	if index == "Value" then
		return self._value
	elseif ValueObject[index] then
		return ValueObject[index]
	elseif index == "_value" then
		return nil -- Edge case
	else
		error(("%q is not a member of ValueObject"):format(tostring(index)))
	end
end

function ValueObject:__newindex(index, value)
	if index == "Value" then
		local previous = rawget(self, "_value")
		if previous ~= value then
			rawset(self, "_value", value)

			local maid = Maid.new()

			self.Changed:Fire(value, previous, maid)

			self._maid._valueMaid = maid
		end
	else
		error(("%q is not a member of ValueObject"):format(tostring(index)))
	end
end

--[=[
	Forces the value to be nil on cleanup, cleans up the Maid

	Does not fire the event since 3.5.0
]=]
function ValueObject:Destroy()
	rawset(self, "_value", nil)
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return ValueObject
