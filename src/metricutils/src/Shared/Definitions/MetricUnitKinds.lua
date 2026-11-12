--!strict
--[=[
	The named kinds of measurement, such as `"length"` and `"speed"`: each a set of dimensions, absolute or a
	difference. [MetricUnit.GetKind], [MetricUnit.isKind] and [MetricUnit.expect] take these names. The dimension
	functions they are built from are in [MetricUnitDimensionUtils].

	```lua
	MetricUnitKinds.SPEED -- { length = 1, time = -1 }
	MetricUnitKinds.fromName("speed") -- { length = 1, time = -1 }, false
	MetricUnitKinds.getKind({ temperature = 1 }, true) -- "temperature"
	```

	@class MetricUnitKinds
]=]

local require = require(script.Parent.loader).load(script)

local MetricUnitDimensionUtils = require("MetricUnitDimensionUtils")

local MetricUnitKinds = {}

type Dimensions = MetricUnitDimensionUtils.Dimensions

--[=[
	A kind's name. `"temperature"` is an absolute temperature and `"temperatureDifference"` a difference between two.
	`"time"` is a span of time and `"instant"` a point in time, measured from an epoch the caller chooses. `"none"` is
	a plain, dimensionless number.

	@type KindName "none" | "time" | "length" | "area" | "volume" | "memory" | "mass" | "rate" | "speed" | "acceleration" | "force" | "energy" | "power" | "pressure" | "density" | "dataRate" | "temperature" | "temperatureDifference" | "instant" | "angle" | "angularVelocity" | "angularAcceleration" | "current" | "charge" | "voltage" | "resistance" | "conductance" | "capacitance" | "inductance" | "magneticFlux" | "magneticFluxDensity" | "amount" | "luminousIntensity" | "solidAngle" | "luminousFlux" | "illuminance" | "absorbedDose" | "catalyticActivity" | "molarMass" | "molarConcentration" | "fuelEconomy"
	@within MetricUnitKinds
]=]
export type KindName =
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
	| "angle"
	| "angularVelocity"
	| "angularAcceleration"
	| "current"
	| "charge"
	| "voltage"
	| "resistance"
	| "conductance"
	| "capacitance"
	| "inductance"
	| "magneticFlux"
	| "magneticFluxDensity"
	| "amount"
	| "luminousIntensity"
	| "solidAngle"
	| "luminousFlux"
	| "illuminance"
	| "absorbedDose"
	| "catalyticActivity"
	| "molarMass"
	| "molarConcentration"
	| "fuelEconomy"

MetricUnitKinds.TIME = table.freeze({ time = 1 }) :: Dimensions
MetricUnitKinds.LENGTH = table.freeze({ length = 1 }) :: Dimensions
MetricUnitKinds.MEMORY = table.freeze({ memory = 1 }) :: Dimensions
MetricUnitKinds.MASS = table.freeze({ mass = 1 }) :: Dimensions
MetricUnitKinds.TEMPERATURE = table.freeze({ temperature = 1 }) :: Dimensions
MetricUnitKinds.ANGLE = table.freeze({ angle = 1 }) :: Dimensions
MetricUnitKinds.CURRENT = table.freeze({ current = 1 }) :: Dimensions
MetricUnitKinds.AMOUNT = table.freeze({ amount = 1 }) :: Dimensions
MetricUnitKinds.LUMINOUS_INTENSITY = table.freeze({ luminousIntensity = 1 }) :: Dimensions

local function times(a: Dimensions, b: Dimensions): Dimensions
	return MetricUnitDimensionUtils.combine(a, b, 1)
end

local function per(a: Dimensions, b: Dimensions): Dimensions
	return MetricUnitDimensionUtils.combine(a, b, -1)
end

MetricUnitKinds.AREA = times(MetricUnitKinds.LENGTH, MetricUnitKinds.LENGTH)
MetricUnitKinds.VOLUME = times(MetricUnitKinds.AREA, MetricUnitKinds.LENGTH)
MetricUnitKinds.RATE = per(MetricUnitDimensionUtils.NONE, MetricUnitKinds.TIME)
MetricUnitKinds.SPEED = per(MetricUnitKinds.LENGTH, MetricUnitKinds.TIME)
MetricUnitKinds.ACCELERATION = per(MetricUnitKinds.SPEED, MetricUnitKinds.TIME)
MetricUnitKinds.FORCE = times(MetricUnitKinds.MASS, MetricUnitKinds.ACCELERATION)
MetricUnitKinds.ENERGY = times(MetricUnitKinds.FORCE, MetricUnitKinds.LENGTH)
MetricUnitKinds.POWER = per(MetricUnitKinds.ENERGY, MetricUnitKinds.TIME)
MetricUnitKinds.PRESSURE = per(MetricUnitKinds.FORCE, MetricUnitKinds.AREA)
MetricUnitKinds.DENSITY = per(MetricUnitKinds.MASS, MetricUnitKinds.VOLUME)
MetricUnitKinds.DATA_RATE = per(MetricUnitKinds.MEMORY, MetricUnitKinds.TIME)
MetricUnitKinds.ANGULAR_VELOCITY = per(MetricUnitKinds.ANGLE, MetricUnitKinds.TIME)
MetricUnitKinds.ANGULAR_ACCELERATION = per(MetricUnitKinds.ANGULAR_VELOCITY, MetricUnitKinds.TIME)
MetricUnitKinds.CHARGE = times(MetricUnitKinds.CURRENT, MetricUnitKinds.TIME)
MetricUnitKinds.VOLTAGE = per(MetricUnitKinds.POWER, MetricUnitKinds.CURRENT)
MetricUnitKinds.RESISTANCE = per(MetricUnitKinds.VOLTAGE, MetricUnitKinds.CURRENT)
MetricUnitKinds.CONDUCTANCE = per(MetricUnitKinds.CURRENT, MetricUnitKinds.VOLTAGE)
MetricUnitKinds.CAPACITANCE = per(MetricUnitKinds.CHARGE, MetricUnitKinds.VOLTAGE)
MetricUnitKinds.MAGNETIC_FLUX = times(MetricUnitKinds.VOLTAGE, MetricUnitKinds.TIME)
MetricUnitKinds.INDUCTANCE = per(MetricUnitKinds.MAGNETIC_FLUX, MetricUnitKinds.CURRENT)
MetricUnitKinds.MAGNETIC_FLUX_DENSITY = per(MetricUnitKinds.MAGNETIC_FLUX, MetricUnitKinds.AREA)
MetricUnitKinds.SOLID_ANGLE = times(MetricUnitKinds.ANGLE, MetricUnitKinds.ANGLE)
MetricUnitKinds.LUMINOUS_FLUX = times(MetricUnitKinds.LUMINOUS_INTENSITY, MetricUnitKinds.SOLID_ANGLE)
MetricUnitKinds.ILLUMINANCE = per(MetricUnitKinds.LUMINOUS_FLUX, MetricUnitKinds.AREA)
MetricUnitKinds.ABSORBED_DOSE = per(MetricUnitKinds.ENERGY, MetricUnitKinds.MASS)
MetricUnitKinds.CATALYTIC_ACTIVITY = per(MetricUnitKinds.AMOUNT, MetricUnitKinds.TIME)
MetricUnitKinds.MOLAR_MASS = per(MetricUnitKinds.MASS, MetricUnitKinds.AMOUNT)
MetricUnitKinds.MOLAR_CONCENTRATION = per(MetricUnitKinds.AMOUNT, MetricUnitKinds.VOLUME)
MetricUnitKinds.FUEL_ECONOMY = per(MetricUnitKinds.LENGTH, MetricUnitKinds.VOLUME)

type NamedKind = { name: KindName, dimensions: Dimensions, absolute: boolean }

local NAMED_KINDS_IN_LOOKUP_ORDER: { NamedKind } = {
	{ name = "none", dimensions = MetricUnitDimensionUtils.NONE, absolute = false },
	{ name = "time", dimensions = MetricUnitKinds.TIME, absolute = false },
	{ name = "length", dimensions = MetricUnitKinds.LENGTH, absolute = false },
	{ name = "area", dimensions = MetricUnitKinds.AREA, absolute = false },
	{ name = "volume", dimensions = MetricUnitKinds.VOLUME, absolute = false },
	{ name = "memory", dimensions = MetricUnitKinds.MEMORY, absolute = false },
	{ name = "mass", dimensions = MetricUnitKinds.MASS, absolute = false },
	{ name = "rate", dimensions = MetricUnitKinds.RATE, absolute = false },
	{ name = "speed", dimensions = MetricUnitKinds.SPEED, absolute = false },
	{ name = "acceleration", dimensions = MetricUnitKinds.ACCELERATION, absolute = false },
	{ name = "force", dimensions = MetricUnitKinds.FORCE, absolute = false },
	{ name = "energy", dimensions = MetricUnitKinds.ENERGY, absolute = false },
	{ name = "power", dimensions = MetricUnitKinds.POWER, absolute = false },
	{ name = "pressure", dimensions = MetricUnitKinds.PRESSURE, absolute = false },
	{ name = "density", dimensions = MetricUnitKinds.DENSITY, absolute = false },
	{ name = "dataRate", dimensions = MetricUnitKinds.DATA_RATE, absolute = false },
	{ name = "temperature", dimensions = MetricUnitKinds.TEMPERATURE, absolute = true },
	{ name = "temperatureDifference", dimensions = MetricUnitKinds.TEMPERATURE, absolute = false },
	{ name = "instant", dimensions = MetricUnitKinds.TIME, absolute = true },
	{ name = "angle", dimensions = MetricUnitKinds.ANGLE, absolute = false },
	{ name = "angularVelocity", dimensions = MetricUnitKinds.ANGULAR_VELOCITY, absolute = false },
	{ name = "angularAcceleration", dimensions = MetricUnitKinds.ANGULAR_ACCELERATION, absolute = false },
	{ name = "current", dimensions = MetricUnitKinds.CURRENT, absolute = false },
	{ name = "charge", dimensions = MetricUnitKinds.CHARGE, absolute = false },
	{ name = "voltage", dimensions = MetricUnitKinds.VOLTAGE, absolute = false },
	{ name = "resistance", dimensions = MetricUnitKinds.RESISTANCE, absolute = false },
	{ name = "conductance", dimensions = MetricUnitKinds.CONDUCTANCE, absolute = false },
	{ name = "capacitance", dimensions = MetricUnitKinds.CAPACITANCE, absolute = false },
	{ name = "inductance", dimensions = MetricUnitKinds.INDUCTANCE, absolute = false },
	{ name = "magneticFlux", dimensions = MetricUnitKinds.MAGNETIC_FLUX, absolute = false },
	{ name = "magneticFluxDensity", dimensions = MetricUnitKinds.MAGNETIC_FLUX_DENSITY, absolute = false },
	{ name = "amount", dimensions = MetricUnitKinds.AMOUNT, absolute = false },
	{ name = "luminousIntensity", dimensions = MetricUnitKinds.LUMINOUS_INTENSITY, absolute = false },
	{ name = "solidAngle", dimensions = MetricUnitKinds.SOLID_ANGLE, absolute = false },
	{ name = "luminousFlux", dimensions = MetricUnitKinds.LUMINOUS_FLUX, absolute = false },
	{ name = "illuminance", dimensions = MetricUnitKinds.ILLUMINANCE, absolute = false },
	{ name = "absorbedDose", dimensions = MetricUnitKinds.ABSORBED_DOSE, absolute = false },
	{ name = "catalyticActivity", dimensions = MetricUnitKinds.CATALYTIC_ACTIVITY, absolute = false },
	{ name = "molarMass", dimensions = MetricUnitKinds.MOLAR_MASS, absolute = false },
	{ name = "molarConcentration", dimensions = MetricUnitKinds.MOLAR_CONCENTRATION, absolute = false },
	{ name = "fuelEconomy", dimensions = MetricUnitKinds.FUEL_ECONOMY, absolute = false },
}

local KIND_BY_NAME: { [string]: NamedKind } = {}
for _, kind in NAMED_KINDS_IN_LOOKUP_ORDER do
	KIND_BY_NAME[kind.name] = table.freeze(kind)
end
table.freeze(NAMED_KINDS_IN_LOOKUP_ORDER)
table.freeze(KIND_BY_NAME)

--[=[
	The dimensions a [KindName] stands for, or the table given, and whether it names an absolute value. Errors on an
	unknown name.

	@param kind KindName | Dimensions
	@return Dimensions
	@return boolean -- whether the name is of an absolute value
]=]
function MetricUnitKinds.fromName(kind: KindName | Dimensions): (Dimensions, boolean)
	if type(kind) == "table" then
		return kind, false
	end
	local named = KIND_BY_NAME[kind]
	if not named then
		error(string.format("MetricUnit: no kind named %q", tostring(kind)), 3)
	end
	return named.dimensions, named.absolute
end

--[=[
	The [KindName] of `dimensions`, absolute or a difference, or nil for a compound without a name.

	```lua
	MetricUnitKinds.getKind({ length = 1, time = -1 }, false) -- "speed"
	MetricUnitKinds.getKind({ temperature = 1 }, true) -- "temperature"
	MetricUnitKinds.getKind({ length = 4 }, false) -- nil
	```

	@param dimensions Dimensions
	@param absolute boolean
	@return KindName?
]=]
function MetricUnitKinds.getKind(dimensions: Dimensions, absolute: boolean): KindName?
	for _, kind in NAMED_KINDS_IN_LOOKUP_ORDER do
		if kind.absolute == absolute and MetricUnitDimensionUtils.equal(kind.dimensions, dimensions) then
			return kind.name
		end
	end
	return nil
end

--[=[
	What a value of `dimensions` is, absolute or a difference: "absolute temperature", "temperature difference",
	"instant", "length/time".

	@param dimensions Dimensions
	@param absolute boolean
	@return string
]=]
function MetricUnitKinds.describeKind(dimensions: Dimensions, absolute: boolean): string
	local formula = MetricUnitDimensionUtils.describe(dimensions)
	if absolute and MetricUnitDimensionUtils.equal(dimensions, MetricUnitKinds.TIME) then
		return "instant"
	elseif absolute then
		return "absolute " .. formula
	elseif MetricUnitDimensionUtils.equal(dimensions, MetricUnitKinds.TEMPERATURE) then
		return formula .. " difference"
	end
	return formula
end

return table.freeze(MetricUnitKinds)
