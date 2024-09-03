--[=[
	Tuple class for Lua

	@class Tuple
]=]

local Tuple = {}
Tuple.ClassName = "Tuple"
Tuple.__index = Tuple

--[=[
	Constructs a new tuple

	@param ... any
	@return Tuple<T>
]=]
function Tuple.new(...)
	return setmetatable(table.pack(...), Tuple)
end

--[=[
	Returns true of the value is a tuple

	@return boolean
]=]
function Tuple.isTuple(value)
	return getmetatable(value) == Tuple
end

--[=[
	Unpacks the tuple

	@return T
]=]
function Tuple:Unpack()
	return table.unpack(self, 1, self.n)
end

--[=[
	Converts to array

	@return { T }
]=]
function Tuple:ToArray()
	return { self:Unpack() }
end

--[=[
	Converts the tuple to a string for easy debugging
]=]
function Tuple:__tostring()
	local converted = {}
	for i=1, self.n do
		converted[i] = tostring(self[i])
	end
	return table.concat(converted, ", ")
end

--[=[
	Returns the length of the tuple

	@return number
]=]
function Tuple:__len()
	return self.n
end

--[=[
	Compares the tuple to another tuple
	@param other Tuple
]=]
function Tuple:__eq(other)
	if not Tuple.isTuple(other) then
		return false
	end

	if self.n ~= other.n then
		return false
	end

	for i=1, self.n do
		if self[i] ~= other[i] then
			return false
		end
	end

	return true
end

--[=[
	Combines the tuple
	@param other Tuple
]=]
function Tuple:__add(other)
	assert(Tuple.isTuple(other), "Can only add tuples")

	local result = Tuple.new(self:Unpack())
	local count = self.n
	for i=1, other.n do
		result[count + i] = other[i]
	end
	result.n = count + other.n
	return result
end

--[=[
	Unpacks the tuple

	@return ...
]=]
function Tuple:__call()
	return table.unpack(self, 1, self.n)
end

return Tuple