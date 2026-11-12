--!strict
--[=[
	Functions over dimensions: frozen tables of integer exponents by name, zero exponents left out, so a speed is
	`{ length = 1, time = -1 }` and a plain number is `{}`. Any name is a dimension; `time`, `length`, `memory`,
	`mass`, `temperature`, `angle`, `current`, `amount` and `luminousIntensity` are the base dimensions [MetricUnit] has units for, and derived ones such as force
	and energy are products of those. The named combinations, such as `"speed"`, are in [MetricUnitKinds].

	```lua
	MetricUnitDimensionUtils.combine({ length = 1 }, { time = 1 }, -1) -- { length = 1, time = -1 }
	MetricUnitDimensionUtils.describe({ length = 1, time = -1 }) -- "length/time"
	```

	@class MetricUnitDimensionUtils
]=]

local MetricUnitDimensionUtils = {}

--[=[
	Integer exponents keyed by dimension name, with zero exponents left out.

	@type Dimensions { [string]: number }
	@within MetricUnitDimensionUtils
]=]
export type Dimensions = { [string]: number }

--[=[
	No dimensions: a plain number's, and what `combine` returns when every exponent cancels.

	@prop NONE Dimensions
	@within MetricUnitDimensionUtils
]=]
MetricUnitDimensionUtils.NONE = table.freeze({}) :: Dimensions

--[=[
	The exponents of `a` plus `sign` times those of `b`: a product when `sign` is 1, a quotient when it is -1.

	@param a Dimensions
	@param b Dimensions
	@param sign number -- 1 or -1
	@return Dimensions
]=]
function MetricUnitDimensionUtils.combine(a: Dimensions, b: Dimensions, sign: number): Dimensions
	local result: Dimensions = table.clone(a)
	for name, exponent in b do
		local total = (result[name] or 0) + sign * exponent
		if total == 0 then
			result[name] = nil
		else
			result[name] = total
		end
	end
	return table.freeze(result)
end

--[=[
	The exponents of `a` times `factor`, erroring if any is not a whole number.

	@param a Dimensions
	@param factor number
	@return Dimensions
]=]
function MetricUnitDimensionUtils.scale(a: Dimensions, factor: number): Dimensions
	local result: Dimensions = {}
	for name, exponent in a do
		local scaled = exponent * factor
		if scaled ~= math.floor(scaled) then
			error(
				string.format(
					"MetricUnit: %s to the power %s has a fractional exponent",
					MetricUnitDimensionUtils.describe(a),
					tostring(factor)
				),
				3
			)
		end
		if scaled ~= 0 then
			result[name] = scaled
		end
	end
	return table.freeze(result)
end

--[=[
	Whether `a` and `b` have the same exponents.

	@param a Dimensions
	@param b Dimensions
	@return boolean
]=]
function MetricUnitDimensionUtils.equal(a: Dimensions, b: Dimensions): boolean
	if a == b then
		return true
	end
	for name, exponent in a do
		if b[name] ~= exponent then
			return false
		end
	end
	for name in b do
		if a[name] == nil then
			return false
		end
	end
	return true
end

--[=[
	Whether `value` is a table of whole-number exponents keyed by name, none of them zero.

	@param value any
	@return boolean
]=]
function MetricUnitDimensionUtils.isDimensions(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	for name, exponent in value do
		if
			type(name) ~= "string"
			or type(exponent) ~= "number"
			or exponent == 0
			or exponent ~= math.floor(exponent)
		then
			return false
		end
	end
	return true
end

--[=[
	A readable formula for `dimensions`: "time", "length/time", "1/time", "length^2" or "dimensionless".

	@param dimensions Dimensions
	@return string
]=]
function MetricUnitDimensionUtils.describe(dimensions: Dimensions): string
	local over: { string } = {}
	local under: { string } = {}
	for _, name in MetricUnitDimensionUtils._sortedNames(dimensions) do
		local exponent = dimensions[name]
		local power = math.abs(exponent)
		local part = if power == 1 then name else name .. "^" .. tostring(power)
		table.insert(if exponent > 0 then over else under, part)
	end
	if #over == 0 and #under == 0 then
		return "dimensionless"
	end
	local text = if #over == 0 then "1" else table.concat(over, "·")
	for _, part in under do
		text ..= "/" .. part
	end
	return text
end

function MetricUnitDimensionUtils._sortedNames(dimensions: Dimensions): { string }
	local names: { string } = {}
	for name in dimensions do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return table.freeze(MetricUnitDimensionUtils)
