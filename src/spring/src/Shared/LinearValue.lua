--[=[
	Represents a value that can operate in linear space

	@class LinearValue
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")

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
	return DuckTypeUtils.isImplementation(LinearValue, value)
end

local function convertUDim2(scaleX, offsetX, scaleY, offsetY)
	-- Roblox UDim2.new(0, 9.999, 0, 9.999) rounds to UDim2.new(0, 9, 0, 9) which means small floating point
	-- errors can cause shaking UI.

	return UDim2.new(scaleX, math.round(offsetX), scaleY, math.round(offsetY))
end

local function convertUDim(scale, offset)
	-- Roblox UDim.new(0, 9.999) rounds to UDim.new(0, 9) which means small floating point
	-- errors can cause shaking UI.

	return UDim.new(scale, math.round(offset))
end

local function convertBoolean(value)
	return value ~= 0
end

--[=[
	Converts an arbitrary value to a LinearValue if Roblox has not defined this value
	for multiplication and addition.

	@param value T
	@return LinearValue<T> | T
]=]
function LinearValue.toLinearIfNeeded(value)
	if typeof(value) == "Color3" then
		return LinearValue.new(Color3.new, {value.r, value.g, value.b})
	elseif typeof(value) == "UDim2" then
		return LinearValue.new(convertUDim2, {value.X.Scale, math.round(value.X.Offset), value.Y.Scale, math.round(value.Y.Offset)})
	elseif typeof(value) == "UDim" then
		return LinearValue.new(convertUDim, {value.Scale, math.round(value.Offset)})
	elseif type(value) == "boolean" then
		return LinearValue.new(convertBoolean, { value and 1 or 0 })
	else
		return value
	end
end

--[=[
	Extracts the base value out of a packed linear value if needed.

	@param value LinearValue<T> | any
	@return T | any
]=]
function LinearValue.fromLinearIfNeeded(value)
	if LinearValue.isLinear(value) then
		return value:ToBaseValue()
	else
		return value
	end
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