---
-- @classmod LinearValue
-- @author Quenty

local LinearValue = {}
LinearValue.ClassName = "LinearValue"
LinearValue.__index = LinearValue

function LinearValue.new(constructor, values)
	return setmetatable({
		_constructor = constructor;
		_values = values;
	}, LinearValue)
end

function LinearValue.isLinear(value)
	return type(value) == "table" and getmetatable(value) == LinearValue
end

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

function LinearValue:GetMagnitude()
	local dot = 0
	for i=1, #self._values do
		local value = self._values[i]
		dot = dot + value*value
	end
	return math.sqrt(dot)
end

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


return LinearValue