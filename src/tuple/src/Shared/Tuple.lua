--[=[
	Tuple class for Lua

	@class Tuple
]=]

local Tuple = {}
Tuple.ClassName = "Tuple"
Tuple.__index = Tuple

function Tuple.new(...)
	return setmetatable(table.pack(...), Tuple)
end

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

function Tuple:__tostring()
	return table.concat(self, ", ")
end

function Tuple:__len()
	return self.n
end

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

function Tuple:__call()
	return table.unpack(self, 1, self.n)
end

return Tuple