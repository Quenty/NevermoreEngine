--- To work like value objects in Roblox and track a single item,
-- with `.Changed` events
-- @classmod ValueObject

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local Maid = require("Maid")

local ValueObject = {}
ValueObject.ClassName = "ValueObject"

--- The value of the ValueObject
-- @tfield Variant Value

--- Event fires when the value's object value change
-- @signal Changed
-- @tparam Variant newValue The new value
-- @tparam Variant oldValue The old value


--- Constructs a new value object
-- @constructor
-- @treturn ValueObject
function ValueObject.new(baseValue)
	local self = {}

	rawset(self, "_value", baseValue)

	self._maid = Maid.new()

	self.Changed = Signal.new() -- :Fire(newValue, oldValue, maid)
	self._maid:GiveTask(self.Changed)

	return setmetatable(self, ValueObject)
end

function ValueObject.isValueObject(value)
	return type(value) == "table" and getmetatable(value) == ValueObject
end

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

--- Forces the value to be nil on cleanup, cleans up the Maid
function ValueObject:Destroy()
	rawset(self, "_value", nil)
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return ValueObject
