--!strict
--[=[
	Dimensions as frozen tables of integer exponents by name, zero exponents left out, so a speed is
	`{ length = 1, time = -1 }` and a plain number is `{}`. Any name is a dimension; `time`, `length`, `memory`,
	`mass` and `temperature` are the base dimensions [MetricUnit] has units for, and the derived ones such as force
	and energy are products of those.

	```lua
	MetricUnitDimensions.combine(MetricUnitDimensions.LENGTH, MetricUnitDimensions.TIME, -1) -- { length = 1, time = -1 }
	MetricUnitDimensions.describe(MetricUnitDimensions.SPEED) -- "length/time"
	```

	@class MetricUnitDimensions
]=]

local MetricUnitDimensions = {}

--[=[
	Integer exponents keyed by dimension name, with zero exponents left out.

	@type Dimensions { [string]: number }
	@within MetricUnitDimensions
]=]
export type Dimensions = { [string]: number }

--[=[
	A name [MetricUnit.expect] takes for a dimension. `"temperature"` is an absolute temperature and
	`"temperatureDifference"` a difference between two. `"time"` is a span of time and `"instant"` a point in time,
	measured from an epoch the caller chooses.

	@type DimensionName "none" | "time" | "length" | "area" | "volume" | "memory" | "mass" | "rate" | "speed" | "acceleration" | "force" | "energy" | "power" | "pressure" | "density" | "dataRate" | "temperature" | "temperatureDifference" | "instant"
	@within MetricUnitDimensions
]=]
export type DimensionName =
	"none"
	| "time"
	| "length"
	| "area"
	| "volume"
	| "memory"
	| "mass"
	| "rate"
	| "speed"
	| "acceleration"
	| "force"
	| "energy"
	| "power"
	| "pressure"
	| "density"
	| "dataRate"
	| "temperature"
	| "temperatureDifference"
	| "instant"

MetricUnitDimensions.NONE = table.freeze({}) :: Dimensions
MetricUnitDimensions.TIME = table.freeze({ time = 1 }) :: Dimensions
MetricUnitDimensions.LENGTH = table.freeze({ length = 1 }) :: Dimensions
MetricUnitDimensions.MEMORY = table.freeze({ memory = 1 }) :: Dimensions
MetricUnitDimensions.MASS = table.freeze({ mass = 1 }) :: Dimensions
MetricUnitDimensions.TEMPERATURE = table.freeze({ temperature = 1 }) :: Dimensions

MetricUnitDimensions.AREA = table.freeze({ length = 2 }) :: Dimensions
MetricUnitDimensions.VOLUME = table.freeze({ length = 3 }) :: Dimensions
MetricUnitDimensions.RATE = table.freeze({ time = -1 }) :: Dimensions
MetricUnitDimensions.SPEED = table.freeze({ length = 1, time = -1 }) :: Dimensions
MetricUnitDimensions.ACCELERATION = table.freeze({ length = 1, time = -2 }) :: Dimensions
MetricUnitDimensions.FORCE = table.freeze({ mass = 1, length = 1, time = -2 }) :: Dimensions
MetricUnitDimensions.ENERGY = table.freeze({ mass = 1, length = 2, time = -2 }) :: Dimensions
MetricUnitDimensions.POWER = table.freeze({ mass = 1, length = 2, time = -3 }) :: Dimensions
MetricUnitDimensions.PRESSURE = table.freeze({ mass = 1, length = -1, time = -2 }) :: Dimensions
MetricUnitDimensions.DENSITY = table.freeze({ mass = 1, length = -3 }) :: Dimensions
MetricUnitDimensions.DATA_RATE = table.freeze({ memory = 1, time = -1 }) :: Dimensions

type NamedKind = { name: DimensionName, dimensions: Dimensions, absolute: boolean }

-- Every DimensionName, in a fixed order so getKind is deterministic
local NAMED_KINDS: { NamedKind } = {
	{ name = "none", dimensions = MetricUnitDimensions.NONE, absolute = false },
	{ name = "time", dimensions = MetricUnitDimensions.TIME, absolute = false },
	{ name = "length", dimensions = MetricUnitDimensions.LENGTH, absolute = false },
	{ name = "area", dimensions = MetricUnitDimensions.AREA, absolute = false },
	{ name = "volume", dimensions = MetricUnitDimensions.VOLUME, absolute = false },
	{ name = "memory", dimensions = MetricUnitDimensions.MEMORY, absolute = false },
	{ name = "mass", dimensions = MetricUnitDimensions.MASS, absolute = false },
	{ name = "rate", dimensions = MetricUnitDimensions.RATE, absolute = false },
	{ name = "speed", dimensions = MetricUnitDimensions.SPEED, absolute = false },
	{ name = "acceleration", dimensions = MetricUnitDimensions.ACCELERATION, absolute = false },
	{ name = "force", dimensions = MetricUnitDimensions.FORCE, absolute = false },
	{ name = "energy", dimensions = MetricUnitDimensions.ENERGY, absolute = false },
	{ name = "power", dimensions = MetricUnitDimensions.POWER, absolute = false },
	{ name = "pressure", dimensions = MetricUnitDimensions.PRESSURE, absolute = false },
	{ name = "density", dimensions = MetricUnitDimensions.DENSITY, absolute = false },
	{ name = "dataRate", dimensions = MetricUnitDimensions.DATA_RATE, absolute = false },
	{ name = "temperature", dimensions = MetricUnitDimensions.TEMPERATURE, absolute = true },
	{ name = "temperatureDifference", dimensions = MetricUnitDimensions.TEMPERATURE, absolute = false },
	{ name = "instant", dimensions = MetricUnitDimensions.TIME, absolute = true },
}

local KIND_BY_NAME: { [string]: NamedKind } = {}
for _, kind in NAMED_KINDS do
	KIND_BY_NAME[kind.name] = table.freeze(kind)
end
table.freeze(NAMED_KINDS)
table.freeze(KIND_BY_NAME)

--[=[
	The [DimensionName] of `dimensions`, absolute or a difference, or nil for a compound without a name.

	```lua
	MetricUnitDimensions.getKind({ length = 1, time = -1 }, false) -- "speed"
	MetricUnitDimensions.getKind({ temperature = 1 }, true) -- "temperature"
	MetricUnitDimensions.getKind({ length = 4 }, false) -- nil
	```

	@param dimensions Dimensions
	@param absolute boolean
	@return DimensionName?
]=]
function MetricUnitDimensions.getKind(dimensions: Dimensions, absolute: boolean): DimensionName?
	for _, kind in NAMED_KINDS do
		if kind.absolute == absolute and MetricUnitDimensions.equal(kind.dimensions, dimensions) then
			return kind.name
		end
	end
	return nil
end

--[=[
	The exponents of `a` plus `sign` times those of `b`: a product when `sign` is 1, a quotient when it is -1.

	@param a Dimensions
	@param b Dimensions
	@param sign number -- 1 or -1
	@return Dimensions
]=]
function MetricUnitDimensions.combine(a: Dimensions, b: Dimensions, sign: number): Dimensions
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
function MetricUnitDimensions.scale(a: Dimensions, factor: number): Dimensions
	local result: Dimensions = {}
	for name, exponent in a do
		local scaled = exponent * factor
		if scaled ~= math.floor(scaled) then
			error(
				string.format(
					"MetricUnit: %s to the power %s has a fractional exponent",
					MetricUnitDimensions.describe(a),
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
function MetricUnitDimensions.equal(a: Dimensions, b: Dimensions): boolean
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
	The dimensions a [DimensionName] stands for, or the table given, and whether it names an absolute value.
	Errors on an unknown name.

	@param kind DimensionName | Dimensions
	@return Dimensions
	@return boolean -- whether the name is of an absolute value
]=]
function MetricUnitDimensions.fromName(kind: DimensionName | Dimensions): (Dimensions, boolean)
	if type(kind) == "table" then
		return kind, false
	end
	local named = KIND_BY_NAME[kind]
	if not named then
		error(string.format("MetricUnit: no dimension named %q", tostring(kind)), 3)
	end
	return named.dimensions, named.absolute
end

--[=[
	Whether `value` is a table of whole-number exponents keyed by name, none of them zero.

	@param value any
	@return boolean
]=]
function MetricUnitDimensions.isDimensions(value: any): boolean
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
	What a value of `dimensions` is, absolute or a difference: "absolute temperature", "temperature difference",
	"length/time".

	@param dimensions Dimensions
	@param absolute boolean
	@return string
]=]
function MetricUnitDimensions.describeKind(dimensions: Dimensions, absolute: boolean): string
	local formula = MetricUnitDimensions.describe(dimensions)
	if absolute and MetricUnitDimensions.equal(dimensions, MetricUnitDimensions.TIME) then
		return "instant"
	elseif absolute then
		return "absolute " .. formula
	elseif MetricUnitDimensions.equal(dimensions, MetricUnitDimensions.TEMPERATURE) then
		return formula .. " difference"
	end
	return formula
end

--[=[
	A readable formula for `dimensions`: "time", "length/time", "1/time", "length^2" or "dimensionless".

	@param dimensions Dimensions
	@return string
]=]
function MetricUnitDimensions.describe(dimensions: Dimensions): string
	local over: { string } = {}
	local under: { string } = {}
	for _, name in MetricUnitDimensions._sortedNames(dimensions) do
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

function MetricUnitDimensions._sortedNames(dimensions: Dimensions): { string }
	local names: { string } = {}
	for name in dimensions do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return table.freeze(MetricUnitDimensions)
