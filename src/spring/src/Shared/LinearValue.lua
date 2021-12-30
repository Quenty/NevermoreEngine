--[=[
	Represents a value that can operate in linear space

	@class LinearValue
]=]
local LinearValue = {}
LinearValue.ClassName = "LinearValue"
LinearValue.__index = LinearValue

--[=[
	Constructs a new LinearValue object.

	@param constructor (number ...) -> T
	@param values ({ number })
	@return LinearValue<T>
]=]
function LinearValue.new(constructor, values)
	return setmetatable({
		_constructor = constructor;
		_values = values;
	}, LinearValue)
end

--[=[
	Returns whether or not a value is a LinearValue object.

	@param value any -- A value to check
	@return boolean -- True if a linear value, false otherwise
]=]
function LinearValue.isLinear(value)
	return type(value) == "table" and getmetatable(value) == LinearValue
end

--[=[
	Converts the value back to the base value

	@return T
]=]
function LinearValue:ToBaseValue()
	return self._constructor(unpack(self._values))
end

local function operation(func)
	return function(a, b)
		if LinearValue.isLinear(a) and LinearValue.isLinear(b) then
			assert(a._constructor == b._constructor, "a is not the same type of linearValue as b")

			local values = {}
			for i=1, #a._values do
				values[i] = func(a._values[i], b._values[i])
			end
			return LinearValue.new(a._constructor, values)
		elseif LinearValue.isLinear(a) then
			if type(b) == "number" then
				local values = {}
				for i=1, #a._values do
					values[i] = func(a._values[i], b)
				end
				return LinearValue.new(a._constructor, values)
			else
				error("Bad type (b)")
			end
		elseif LinearValue.isLinear(b) then
			if type(a) == "number" then
				local values = {}
				for i=1, #b._values do
					values[i] = func(a, b._values[i])
				end
				return LinearValue.new(b._constructor, values)
			else
				error("Bad type (a)")
			end
		else
			error("Neither value is a linearValue")
		end
	end
end

--[=[
	Returns the magnitude of the linear value.

	@return number -- The magnitude of the linear value.
]=]
function LinearValue:GetMagnitude()
	local dot = 0
	for i=1, #self._values do
		local value = self._values[i]
		dot = dot + value*value
	end
	return math.sqrt(dot)
end

--[=[
	Returns the magnitude of the linear value.

	@prop magnitude number
	@readonly
	@within LinearValue
]=]
function LinearValue:__index(key)
	if LinearValue[key] then
		return LinearValue[key]
	elseif key == "magnitude" then
		return self:GetMagnitude()
	else
		return nil
	end
end

LinearValue.__add = operation(function(a, b)
	return a + b
end)

LinearValue.__sub = operation(function(a, b)
	return a - b
end)

LinearValue.__mul = operation(function(a, b)
	return a * b
end)

LinearValue.__div = operation(function(a, b)
	return a / b
end)

function LinearValue:__eq(a, b)
	if LinearValue.isLinear(a) and LinearValue.isLinear(b) then
		if #a._values ~= #b._values then
			return false
		end

		for i=1, #a._values do
			if a._values[i] ~= b._values[i] then
				return false
			end
		end

		return true
	else
		return false
	end
end


return LinearValue