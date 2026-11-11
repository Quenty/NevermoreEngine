--!strict
--[=[
	A system of units: the units it declares, the units a value is shown in when it prefers this system, and the
	system it falls back to for everything else. Metric is the base: every unit is sized in SI units, and a value
	made from a metric unit prefers nothing. US customary, British imperial and Roblox studs are systems
	([MetricUnitSystems]), and a game can declare its own, such as studs at another scale.

	A value made from a system's unit shows itself in that system, so studs read back as studs. To show any value
	in a system, convert it with [MetricUnit.ToSystem] or ask the system to [MetricUnitSystem.Format] it.

	```lua
	local MINI = MetricUnitSystems.roblox({ name = "robloxMini", metersPerStud = 0.028 })

	local height = MINI:New(5, "stud") -- 14 cm
	MetricUnit.format(height) -- "5 studs"
	MINI:In(height, "stud") -- 5
	height:In("meter") -- 0.14

	MetricUnitSystems.IMPERIAL:Format(MetricUnit.new(2, "liter")) -- "3.52 imp pt"
	```

	Every amount is held in SI units, so values made through different systems add, compare and convert freely.

	@class MetricUnitSystem
]=]

local require = require(script.Parent.loader).load(script)

local MetricUnitDefinitions = require("MetricUnitDefinitions")
local MetricUnitDimensionUtils = require("MetricUnitDimensionUtils")

type UnitDefinition = MetricUnitDefinitions.UnitDefinition

local MetricUnitSystem = {}
MetricUnitSystem.ClassName = "MetricUnitSystem"
MetricUnitSystem.__index = MetricUnitSystem

-- MetricUnit and its formatter require the well-known systems, so this requires them back only when called
local function requireWhenCalled(moduleName: string): any
	return (require :: any)(moduleName)
end

local SYSTEM_BY_OWN_UNIT: { [UnitDefinition]: MetricUnitSystem } = setmetatable({} :: any, { __mode = "kv" })

--[=[
	What a system is made from.

	- `units` are the units it declares, from [MetricUnitDefinitions.createUnits]. They take the place of a
	  well-known unit of the same id, so a system can rescale `stud` and keep its names and translations.
	- `displayUnits` lists, for each dimension, the unit ids to choose from by size, largest first.
	- `pointDisplayUnits` does the same for absolute values, such as `{ "celsius" }` for temperatures.
	- `fallback` is the system asked for any dimension this one does not list.

	@interface MetricUnitSystemConfig
	.name string
	.units { UnitDefinition }?
	.displayUnits { { string } }?
	.pointDisplayUnits { { string } }?
	.fallback MetricUnitSystem?
	@within MetricUnitSystem
]=]
export type MetricUnitSystemConfig = {
	name: string,
	units: { UnitDefinition }?,
	displayUnits: { { string } }?,
	pointDisplayUnits: { { string } }?,
	fallback: MetricUnitSystem?,
}

export type MetricUnitSystem = typeof(setmetatable(
	{} :: {
		_name: string,
		_units: { UnitDefinition },
		_unitsById: { [string]: UnitDefinition },
		_displayUnitIds: { { string } },
		_pointDisplayUnitIds: { { string } },
		_resolved: { displayUnits: { { UnitDefinition } }?, pointDisplayUnits: { { UnitDefinition } }? },
		_fallback: MetricUnitSystem?,
	},
	{} :: typeof({ __index = MetricUnitSystem })
))

--[=[
	A system from `config`. See [MetricUnitSystemConfig].

	@param config MetricUnitSystemConfig
	@return MetricUnitSystem
]=]
function MetricUnitSystem.new(config: MetricUnitSystemConfig): MetricUnitSystem
	assert(type(config) == "table", "Bad config")
	assert(type(config.name) == "string", "Bad config.name")
	assert(config.fallback == nil or MetricUnitSystem.isSystem(config.fallback), "Bad config.fallback")

	local units: { UnitDefinition } = config.units or {}
	local unitsById: { [string]: UnitDefinition } = {}
	for _, unit in units do
		unitsById[unit.id] = unit
	end

	local self: MetricUnitSystem = setmetatable({} :: any, MetricUnitSystem)
	for _, unit in units do
		SYSTEM_BY_OWN_UNIT[unit] = self
	end
	self._name = config.name
	self._units = table.freeze(table.clone(units))
	self._unitsById = table.freeze(unitsById)
	self._fallback = config.fallback
	self._displayUnitIds = table.freeze(table.clone(config.displayUnits or {}))
	self._pointDisplayUnitIds = table.freeze(table.clone(config.pointDisplayUnits or {}))
	self._resolved = {}
	return table.freeze(self :: any)
end

--[=[
	The system that declared `unit` in its config, or nil for a well-known unit.

	@param unit UnitDefinition
	@return MetricUnitSystem?
]=]
function MetricUnitSystem.getSystemDeclaring(unit: UnitDefinition): MetricUnitSystem?
	return SYSTEM_BY_OWN_UNIT[unit]
end

--[=[
	Whether `value` is a [MetricUnitSystem].

	@param value any
	@return boolean
]=]
function MetricUnitSystem.isSystem(value: any): boolean
	return type(value) == "table" and getmetatable(value) == MetricUnitSystem
end

--[=[
	The system's name, such as `"imperial"`.

	@return string
]=]
function MetricUnitSystem.GetName(self: MetricUnitSystem): string
	return self._name
end

--[=[
	The system asked for the dimensions this one does not list, or nil.

	@return MetricUnitSystem?
]=]
function MetricUnitSystem.GetFallback(self: MetricUnitSystem): MetricUnitSystem?
	return self._fallback
end

--[=[
	The units this system declares itself, not counting its fallbacks.

	@return { UnitDefinition }
]=]
function MetricUnitSystem.GetUnits(self: MetricUnitSystem): { UnitDefinition }
	return self._units
end

--[=[
	The unit `unit` names in this system: its own, then its fallbacks', then the well-known one. A unit given
	itself is returned as it is. The result can be passed anywhere a unit is named, and keeps this system's scale.

	```lua
	height:As(MINI:GetUnit("stud"))
	```

	@param unit UnitLike
	@return UnitDefinition?
]=]
function MetricUnitSystem.GetUnit(self: MetricUnitSystem, unit: string | UnitDefinition): UnitDefinition?
	if type(unit) ~= "string" then
		return MetricUnitDefinitions.getUnit(unit)
	end
	local system: MetricUnitSystem? = self
	while system do
		local own = system._unitsById[unit]
		if own then
			return own
		end
		system = system._fallback
	end
	return MetricUnitDefinitions.getUnit(unit)
end

--[=[
	The units a value of `dimensions` is shown in when it prefers this system, largest first: this system's, then
	its fallbacks', or nil when none lists the dimension. An absolute value takes the point display units first.

	@param dimensions Dimensions
	@param absolute boolean?
	@return { UnitDefinition }?
]=]
function MetricUnitSystem.GetDisplayUnits(
	self: MetricUnitSystem,
	dimensions: MetricUnitDimensionUtils.Dimensions,
	absolute: boolean?
): { UnitDefinition }?
	local system: MetricUnitSystem? = self
	while system do
		local displayUnits, pointDisplayUnits = system:_getDisplayUnitLists()
		local found = (absolute and MetricUnitSystem._findByDimensions(pointDisplayUnits, dimensions))
			or MetricUnitSystem._findByDimensions(displayUnits, dimensions)
		if found then
			return found
		end
		system = system._fallback
	end
	return nil
end

--[=[
	`amount` of this system's `unit`, such as `MINI:New(5, "stud")`.

	@param amount number
	@param unit UnitLike
	@return MetricUnit
]=]
function MetricUnitSystem.New(self: MetricUnitSystem, amount: number, unit: string | UnitDefinition): any
	local MetricUnit = requireWhenCalled("MetricUnit")
	return MetricUnit.new(amount, self:_requireUnit(unit, "New"))
end

--[=[
	How many of this system's `unit` `value` is, such as `MINI:In(height, "stud")`.

	@param value MetricUnit
	@param unit UnitLike
	@return number
]=]
function MetricUnitSystem.In(self: MetricUnitSystem, value: any, unit: string | UnitDefinition): number
	return value:In(self:_requireUnit(unit, "In"))
end

--[=[
	Text for players with `value` in this system's units where it has them, as [MetricUnit.format] writes it.

	```lua
	MetricUnitSystems.IMPERIAL:Format(MetricUnit.kilograms(80)) -- "12.598 st"
	```

	@param value MetricUnit | MetricUnitData
	@param options MetricUnitFormatOptions?
	@return string
]=]
function MetricUnitSystem.Format(self: MetricUnitSystem, value: any, options: any?): string
	local MetricUnitFormatUtils = requireWhenCalled("MetricUnitFormatUtils")
	return MetricUnitFormatUtils._formatInSystem(value, self, options)
end

--[=[
	Reads `text` as [MetricUnit.parse] does, with this system's units: `MINI:Parse("5 studs")` is five of its
	studs.

	@param text string
	@param kind (KindName | Dimensions)?
	@param options ParseOptions?
	@return MetricUnit?
	@return string? -- why it could not be read
]=]
function MetricUnitSystem.Parse(self: MetricUnitSystem, text: string, kind: any?, options: any?): (any?, string?)
	local MetricUnit = requireWhenCalled("MetricUnit")
	return MetricUnit._parseInSystem(text, kind, options, self)
end

function MetricUnitSystem._requireUnit(
	self: MetricUnitSystem,
	unit: string | UnitDefinition,
	verb: string
): UnitDefinition
	local definition = self:GetUnit(unit)
	if not definition then
		error(string.format("MetricUnitSystem:%s: %q knows no unit %q", verb, self._name, tostring(unit)), 3)
	end
	return definition
end

function MetricUnitSystem._findByDimensions(
	lists: { { UnitDefinition } },
	dimensions: MetricUnitDimensionUtils.Dimensions
): { UnitDefinition }?
	for _, units in lists do
		if MetricUnitDimensionUtils.equal(units[1].dimensions, dimensions) then
			return units
		end
	end
	return nil
end

function MetricUnitSystem._getDisplayUnitLists(self: MetricUnitSystem): ({ { UnitDefinition } }, { { UnitDefinition } })
	local resolved = self._resolved
	local displayUnits = resolved.displayUnits
	local pointDisplayUnits = resolved.pointDisplayUnits
	if displayUnits and pointDisplayUnits then
		return displayUnits, pointDisplayUnits
	end
	local newDisplayUnits = self:_resolveDisplayUnits(self._displayUnitIds)
	local newPointDisplayUnits = self:_resolveDisplayUnits(self._pointDisplayUnitIds)
	resolved.displayUnits = newDisplayUnits
	resolved.pointDisplayUnits = newPointDisplayUnits
	return newDisplayUnits, newPointDisplayUnits
end

function MetricUnitSystem._resolveDisplayUnits(self: MetricUnitSystem, lists: { { string } }): { { UnitDefinition } }
	local resolved: { { UnitDefinition } } = {}
	for _, ids in lists do
		local units: { UnitDefinition } = {}
		for _, id in ids do
			local unit = self:GetUnit(id)
			if not unit then
				error(string.format("MetricUnitSystem %q knows no unit %q", self._name, id), 4)
			end
			table.insert(units, unit)
		end
		assert(#units > 0, "Empty display unit list")
		table.insert(resolved, table.freeze(units))
	end
	return table.freeze(resolved)
end

return MetricUnitSystem
