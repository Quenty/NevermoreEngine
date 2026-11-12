--!strict
--[=[
	Which unit to display a value in when the caller does not name one: for each dimension, the units to choose from
	by size (`2500 m` displays as `2.5 km`), the time unit a rate is displayed per, and the SI symbols for an unnamed
	compound. Used by [MetricUnitFormatUtils].

	@class MetricUnitDisplayUnitUtils
]=]

local require = require(script.Parent.loader).load(script)

local MetricUnitDefinitions = require("MetricUnitDefinitions")
local MetricUnitDimensionUtils = require("MetricUnitDimensionUtils")
local MetricUnitSystem = require("MetricUnitSystem")
local MetricUnitSystems = require("MetricUnitSystems")

local MetricUnitDisplayUnitUtils = {}

type UnitDefinition = MetricUnitDefinitions.UnitDefinition

local PER_UNIT_IDS_SHORTEST_FIRST: { string } = table.freeze({ "second", "minute", "hour", "day", "year" })
local perUnitsShortestFirst: { UnitDefinition }? = nil

local SI_BASE_UNIT_SYMBOLS: { [string]: string } = table.freeze({
	time = "s",
	length = "m",
	memory = "B",
	mass = "kg",
	temperature = "K",
	angle = "rad",
	current = "A",
	amount = "mol",
	luminousIntensity = "cd",
}) :: any

--[=[
	The units a value of `dimensions` is shown in, largest first, from `system` and its fallbacks ([MetricUnitSystems.METRIC]
	by default), or nil when none lists the dimension. An absolute value is shown on a scale people read, °C rather
	than kelvin, where the system has one.

	@param dimensions Dimensions
	@param system MetricUnitSystem?
	@param absolute boolean?
	@return { UnitDefinition }?
]=]
function MetricUnitDisplayUnitUtils.getDisplayUnits(
	dimensions: MetricUnitDimensionUtils.Dimensions,
	system: MetricUnitSystem.MetricUnitSystem?,
	absolute: boolean?
): { UnitDefinition }?
	return MetricUnitSystem.GetDisplayUnits(system or MetricUnitSystems.METRIC, dimensions, absolute)
end

--[=[
	The largest unit on `units` that `amount` base units fills at least once, the smallest when it fills none, or
	[MetricUnitDisplayUnitUtils.getBaseUnit] when `amount` is zero.

	@param amount number
	@param units { UnitDefinition }
	@return UnitDefinition
]=]
function MetricUnitDisplayUnitUtils.pickDisplayUnit(amount: number, units: { UnitDefinition }): UnitDefinition
	if amount == 0 then
		return MetricUnitDisplayUnitUtils.getBaseUnit(units)
	end
	for _, unit in units do
		if math.abs(amount / unit.factor) >= 1 then
			return unit
		end
	end
	return units[#units]
end

--[=[
	The unit on `units` that is one SI base unit, or the smallest when none is.

	@param units { UnitDefinition }
	@return UnitDefinition
]=]
function MetricUnitDisplayUnitUtils.getBaseUnit(units: { UnitDefinition }): UnitDefinition
	for _, unit in units do
		if unit.factor == 1 then
			return unit
		end
	end
	return units[#units]
end

--[=[
	The shortest time unit that a rate of `amount` per second reaches at least once over, or a year when none does.

	@param amount number -- per second
	@return UnitDefinition
]=]
function MetricUnitDisplayUnitUtils.pickDisplayPerUnit(amount: number): UnitDefinition
	local units = MetricUnitDisplayUnitUtils._perUnitsShortestFirst()
	for _, unit in units do
		if math.abs(amount * unit.factor) >= 1 then
			return unit
		end
	end
	return units[#units]
end

function MetricUnitDisplayUnitUtils._perUnitsShortestFirst(): { UnitDefinition }
	local found = perUnitsShortestFirst
	if found then
		return found
	end
	local units: { UnitDefinition } = {}
	for _, id in PER_UNIT_IDS_SHORTEST_FIRST do
		table.insert(units, (assert(MetricUnitDefinitions.getUnit(id), id)))
	end
	local frozen = table.freeze(units)
	perUnitsShortestFirst = frozen
	return frozen
end

--[=[
	The SI base unit symbol for a dimension name, such as `"m"` for `"length"`, or the name itself when it has none.

	@param name string
	@return string
]=]
function MetricUnitDisplayUnitUtils.getBaseSymbol(name: string): string
	return SI_BASE_UNIT_SYMBOLS[name] or name
end

return table.freeze(MetricUnitDisplayUnitUtils)
