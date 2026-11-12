--!strict
--[=[
	The well-known [MetricUnitSystem]s, and a builder for Roblox systems at a game's own scale.

	- `METRIC`: SI and the metric units people read, such as km, kg, L and °C. The default for every value.
	- `US_CUSTOMARY`: the United States: US gallons, quarts and cups, short tons, mpg (US).
	- `IMPERIAL`: Britain: imperial gallons, pints and fluid ounces, stone, mpg (UK).
	- `US_CUSTOMARY_AND_IMPERIAL`: the units both share, which the two fall back to: miles, feet and inches, mph,
	  pounds, BTU, horsepower, psi, °F.
	- `ROBLOX`: studs against the default avatar, 28 cm each, with studs per second and Roblox mass units.

	A value shows itself in the system of the unit it was made from. To show it in another, convert it or ask
	that system to format it:

	```lua
	local MINI = MetricUnitSystems.roblox({ name = "robloxMini", metersPerStud = 0.028 })

	local speed = MINI:New(part.AssemblyLinearVelocity.Magnitude, "studPerSecond")
	MetricUnit.format(speed) -- in the game's studs per second
	MetricUnitSystems.IMPERIAL:Format(speed) -- in mph, for a player who chose imperial
	MetricUnit.format(speed:ToMetric()) -- in m/s
	```

	@class MetricUnitSystems
]=]

local require = require(script.Parent.loader).load(script)

local MetricUnitDefinitions = require("MetricUnitDefinitions")
local MetricUnitSystem = require("MetricUnitSystem")

local MetricUnitSystems = {}

--[=[
	SI and the metric units people read.

	@prop METRIC MetricUnitSystem
	@within MetricUnitSystems
]=]
MetricUnitSystems.METRIC = MetricUnitSystem.new({
	name = "metric",
	displayUnits = {
		{ "year", "day", "hour", "minute", "second", "millisecond", "microsecond" },
		{ "kilometer", "meter", "centimeter", "millimeter", "micrometer", "nanometer" },
		{ "squareKilometer", "squareMeter", "squareCentimeter", "squareMillimeter" },
		{ "cubicMeter", "liter", "milliliter" },
		{ "petabyte", "terabyte", "gigabyte", "megabyte", "kilobyte", "byte" },
		{ "tonne", "kilogram", "gram", "milligram", "microgram" },
		{ "meterPerSecondSquared" },
		{ "meganewton", "kilonewton", "newton" },
		{ "megajoule", "kilojoule", "joule" },
		{ "gigawatt", "megawatt", "kilowatt", "watt", "milliwatt" },
		{ "megapascal", "kilopascal", "pascal" },
		{ "kilogramPerCubicMeter" },
		{ "kelvin" },
		{ "degree" },
		{ "degreePerSecond" },
		{ "radianPerSecondSquared" },
		{ "ampere", "milliampere", "microampere" },
		{ "coulomb" },
		{ "kilovolt", "volt", "millivolt" },
		{ "megohm", "kilohm", "ohm" },
		{ "siemens" },
		{ "farad", "microfarad", "nanofarad", "picofarad" },
		{ "henry", "millihenry", "microhenry" },
		{ "weber" },
		{ "tesla", "millitesla" },
		{ "kilomole", "mole", "millimole", "micromole" },
		{ "gramPerMole" },
		{ "molePerLiter", "millimolePerLiter" },
		{ "katal" },
		{ "candela" },
		{ "steradian" },
		{ "lumen" },
		{ "kilolux", "lux" },
		{ "gray", "milligray" },
		{ "kilometerPerLiter" },
	},
	pointDisplayUnits = {
		{ "celsius" },
	},
})

--[=[
	The units the United States and Britain share, which [MetricUnitSystems.US_CUSTOMARY] and
	[MetricUnitSystems.IMPERIAL] fall back to before metric.

	@prop US_CUSTOMARY_AND_IMPERIAL MetricUnitSystem
	@within MetricUnitSystems
]=]
MetricUnitSystems.US_CUSTOMARY_AND_IMPERIAL = MetricUnitSystem.new({
	name = "usCustomaryAndImperial",
	displayUnits = {
		{ "mile", "foot", "inch" },
		{ "squareMile", "acre", "squareFoot", "squareInch" },
		{ "milePerHour" },
		{ "footPerSecondSquared" },
		{ "poundForce" },
		{ "britishThermalUnit" },
		{ "horsepower" },
		{ "poundForcePerSquareInch" },
		{ "poundPerCubicFoot" },
		{ "fahrenheit" },
	},
	fallback = MetricUnitSystems.METRIC,
})

--[=[
	United States customary units.

	@prop US_CUSTOMARY MetricUnitSystem
	@within MetricUnitSystems
]=]
MetricUnitSystems.US_CUSTOMARY = MetricUnitSystem.new({
	name = "usCustomary",
	displayUnits = {
		{ "usGallon", "usQuart", "usCup", "usFluidOunce", "usTablespoon", "usTeaspoon" },
		{ "shortTon", "pound", "ounce" },
		{ "milePerUsGallon" },
	},
	fallback = MetricUnitSystems.US_CUSTOMARY_AND_IMPERIAL,
})

--[=[
	British imperial units.

	@prop IMPERIAL MetricUnitSystem
	@within MetricUnitSystems
]=]
MetricUnitSystems.IMPERIAL = MetricUnitSystem.new({
	name = "imperial",
	displayUnits = {
		{ "imperialGallon", "imperialPint", "imperialFluidOunce" },
		{ "stone", "pound", "ounce" },
		{ "milePerImperialGallon" },
	},
	fallback = MetricUnitSystems.US_CUSTOMARY_AND_IMPERIAL,
})

--[=[
	The options for [MetricUnitSystems.roblox].

	@interface RobloxSystemConfig
	.name string
	.metersPerStud number
	.fallback MetricUnitSystem? -- defaults to METRIC
	@within MetricUnitSystems
]=]
export type RobloxSystemConfig = {
	name: string,
	metersPerStud: number,
	fallback: MetricUnitSystem.MetricUnitSystem?,
}

--[=[
	A Roblox system at a stud of `metersPerStud`: `stud`, `studPerSecond`, `studPerSecondSquared` and
	`robloxMassUnit` at that scale, shown for lengths, speeds, accelerations and masses, and `fallback` (metric by
	default) for everything else.

	```lua
	local GIANT = MetricUnitSystems.roblox({ name = "robloxGiant", metersPerStud = 2.8 })
	GIANT:New(10, "stud"):In("meter") -- 28
	```

	@param config RobloxSystemConfig
	@return MetricUnitSystem
]=]
function MetricUnitSystems.roblox(config: RobloxSystemConfig): MetricUnitSystem.MetricUnitSystem
	assert(type(config) == "table", "Bad config")
	return MetricUnitSystem.new({
		name = config.name,
		units = MetricUnitDefinitions.createRobloxUnits(config.name, config.metersPerStud),
		displayUnits = {
			{ "stud" },
			{ "studPerSecond" },
			{ "studPerSecondSquared" },
			{ "robloxMassUnit" },
		},
		fallback = config.fallback or MetricUnitSystems.METRIC,
	})
end

--[=[
	Studs against the default Roblox avatar, 28 cm each.

	@prop ROBLOX MetricUnitSystem
	@within MetricUnitSystems
]=]
MetricUnitSystems.ROBLOX = MetricUnitSystems.roblox({
	name = "roblox",
	metersPerStud = MetricUnitDefinitions.ROBLOX_METERS_PER_STUD,
})

local WELL_KNOWN_BY_NAME: { [string]: MetricUnitSystem.MetricUnitSystem } = {}
for _, system in
	{
		MetricUnitSystems.METRIC,
		MetricUnitSystems.US_CUSTOMARY_AND_IMPERIAL,
		MetricUnitSystems.US_CUSTOMARY,
		MetricUnitSystems.IMPERIAL,
		MetricUnitSystems.ROBLOX,
	}
do
	WELL_KNOWN_BY_NAME[system:GetName()] = system
end
table.freeze(WELL_KNOWN_BY_NAME)

--[=[
	The system that declares `unit`: a game's own system for its units, a well-known one such as `IMPERIAL` for
	`imperialPint`, or nil for units every system shares, such as the second.

	@param unit UnitDefinition
	@return MetricUnitSystem?
]=]
function MetricUnitSystems.getSystemOfUnit(
	unit: MetricUnitDefinitions.UnitDefinition
): MetricUnitSystem.MetricUnitSystem?
	local declaring = MetricUnitSystem.getSystemDeclaring(unit)
	if declaring then
		return declaring
	end
	return if unit.system then WELL_KNOWN_BY_NAME[unit.system] else nil
end

return table.freeze(MetricUnitSystems)
