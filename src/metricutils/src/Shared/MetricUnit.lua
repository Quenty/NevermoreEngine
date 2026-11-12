--!strict
--[=[
	A measurement that knows what it measures: an amount in SI base units with integer exponents for each dimension.
	Time is held in seconds, length in metres, mass in kilograms, memory in bytes, temperature in kelvin, angle in
	radians, current in amperes, amount of substance in moles and luminous intensity in candelas: the SI base units,
	with bytes and radians added. Derived
	quantities such as speed, force, energy and power are products of those, so `MetricUnit.new(1, "newton")` and
	`MetricUnit.kilograms(1) * MetricUnit.meters(1) / MetricUnit.pow(MetricUnit.seconds(1), 2)` are the same value.

	Every unit has one id, such as `"kilometer"`, used to read and write it, and one constructor, such as
	[MetricUnit.kilometers]. Read a value in any unit of its dimension with [MetricUnit.In].

	Values are frozen, and every operation returns a new one. `*` and `/` combine dimensions, a plain number scales,
	and `+`, `-`, `<`, `<=` and `==` need the same dimension on both sides. A plain `0` is zero of whatever dimension it
	meets in `+`, `-` and the helpers; any other plain number is dimensionless.

	A value is either a difference, which scales and adds freely, or absolute, a point on a scale such as a
	temperature in °C or an instant in time. [MetricUnit.new] makes points on the temperature scales and differences
	in every other unit; [MetricUnit.point] and [MetricUnit.difference] make either in any unit. Two absolutes subtract to a difference, an absolute and a difference add to an
	absolute, and an absolute cannot be added to another, negated, multiplied or divided, kelvin included.

	```lua
	local speed = MetricUnit.kilometers(36) / MetricUnit.hours(1)
	speed:In("meterPerSecond") -- 10
	speed:In("milePerHour") -- 22.37
	speed:GetKind() -- "speed"
	MetricUnit.format(speed) -- "10 m/s"

	local power = MetricUnit.new(3, "kilowattHour") / MetricUnit.hours(1)
	power:In("kilowatt") -- 3

	local reach = MetricUnit.expect(MetricUnit.studs(100), "length", "reach") -- 28, in metres

	local swing = MetricUnit.difference(12, "celsius")
	(MetricUnit.celsius(15) + swing):In("celsius") -- 27
	(MetricUnit.celsius(15) - MetricUnit.celsius(10)):In("kelvin") -- 5
	```

	Time is elapsed time in exact seconds. [MetricUnit.years] and [MetricUnit.months] are averages for long-range math
	(a Julian year of 365.25 days, and a twelfth of it), not calendar spans; move a date by calendar months with
	`Time.add` from `@quenty/time`. [MetricUnit.InSeconds] hands exact seconds to `task.wait`, `os.time` and
	`TimeDurationUtils`. [MetricUnit.instant] makes a point in time on any epoch, and [MetricUnit.fromDateTime] and
	[MetricUnit.ToDateTime] cross to and from `DateTime`.

	[MetricUnit.format] writes a value for players, localized, and [MetricUnit.parse] reads one back. A value is
	written in the system of the unit it was made from (miles stay miles, studs stay studs), and metric when made
	from a metric unit. Convert it ([MetricUnit.ToMetric], [MetricUnit.ToImperial]) or pin one unit
	([MetricUnit.As]) to write it otherwise; the locale never chooses. `tostring` is a fixed English debug string.

	Luau cannot compare a table with a number, so `x < 0` and `x == 0` do not work; use [MetricUnit.sign] and
	[MetricUnit.isZero].

	@class MetricUnit
]=]

local require = require(script.Parent.loader).load(script)

local MetricUnitDefinitions = require("MetricUnitDefinitions")
local MetricUnitDimensionUtils = require("MetricUnitDimensionUtils")
local MetricUnitDisplayUnitUtils = require("MetricUnitDisplayUnitUtils")
local MetricUnitFormatUtils = require("MetricUnitFormatUtils")
local MetricUnitKinds = require("MetricUnitKinds")
local MetricUnitParseUtils = require("MetricUnitParseUtils")
local MetricUnitSystem = require("MetricUnitSystem")
local MetricUnitSystems = require("MetricUnitSystems")

local TOSTRING_FORMAT_OPTIONS: MetricUnitFormatUtils.MetricUnitFormatOptions =
	table.freeze({ maximumSignificantDigits = 4 })

local MetricUnit = {}
MetricUnit.ClassName = "MetricUnit"
MetricUnit.__index = MetricUnit

export type Dimensions = MetricUnitDimensionUtils.Dimensions
export type KindName = MetricUnitKinds.KindName

--[=[
	See [MetricUnitDefinitions.UnitId].

	@type UnitId MetricUnitDefinitions.UnitId
	@within MetricUnit
]=]
export type UnitId = MetricUnitDefinitions.UnitId

--[=[
	See [MetricUnitDefinitions.UnitLike].

	@type UnitLike MetricUnitDefinitions.UnitLike
	@within MetricUnit
]=]
export type UnitLike = MetricUnitDefinitions.UnitLike

--[=[
	See [MetricUnitFormatUtils.MetricUnitFormatOptions].

	@type FormatOptions MetricUnitFormatUtils.MetricUnitFormatOptions
	@within MetricUnit
]=]
export type FormatOptions = MetricUnitFormatUtils.MetricUnitFormatOptions

--[=[
	See [MetricUnitFormatUtils.MetricUnitData].

	@type MetricUnitData MetricUnitFormatUtils.MetricUnitData
	@within MetricUnit
]=]
export type MetricUnitData = MetricUnitFormatUtils.MetricUnitData
type System = MetricUnitSystem.MetricUnitSystem
type DisplayPreference = { system: System?, unit: MetricUnitDefinitions.UnitDefinition? }

-- Metatable typed as the whole class, not { __index = MetricUnit }, so the checker sees the metamethods
export type MetricUnit = typeof(setmetatable(
	{} :: {
		_amount: number,
		_dimensions: Dimensions,
		_absolute: boolean,
		_display: DisplayPreference?,
	},
	{} :: typeof(MetricUnit)
))

--[=[
	`amount` of the unit `unit`: the constructor for every unit. The common ones also have their own, such as
	[MetricUnit.meters]; the rest, and units chosen at runtime, use this. A temperature scale gives an absolute
	temperature, as [MetricUnit.celsius] does.

	```lua
	MetricUnit.new(5, "kilometer") == MetricUnit.kilometers(5) -- true
	MetricUnit.new(90, "minutes") == MetricUnit.hours(1.5) -- true
	MetricUnit.new(60, "milePerHour")
	```

	@param amount number
	@param unit UnitLike
	@return MetricUnit
]=]
function MetricUnit.new(amount: number, unit: UnitLike): MetricUnit
	return MetricUnit._fromUnit(amount, unit, "new")
end
--[=[
	A point `amount` of `unit` from that unit's zero: a reading on a scale rather than a change along it. A unit's zero
	is where its scale starts, such as -273.15 °C for kelvin, and is 0 for every unit but the temperature scales; time
	units count from an epoch the caller chooses, as [MetricUnit.instant] does.

	```lua
	MetricUnit.point(20, "celsius") == MetricUnit.celsius(20) -- true
	MetricUnit.point(90, "second") == MetricUnit.instant(90) -- true
	```

	@param amount number
	@param unit UnitLike
	@return MetricUnit
]=]
function MetricUnit.point(amount: number, unit: UnitLike): MetricUnit
	local definition = MetricUnit._definitionFor(amount, unit, "point", 3)
	return MetricUnit._new(
		amount * definition.factor + (definition.zero or 0),
		definition.dimensions,
		true,
		MetricUnit._displayOfUnit(definition)
	)
end
--[=[
	A difference of `amount` of `unit`: a change along a scale rather than a reading on it. Most units already make
	differences with [MetricUnit.new]; this is for the temperature scales, whose readings are points.

	```lua
	MetricUnit.difference(12, "celsius"):In("kelvin") -- 12
	MetricUnit.difference(9, "fahrenheit"):In("kelvin") -- 5
	(MetricUnit.celsius(15) + MetricUnit.difference(12, "celsius")):In("celsius") -- 27
	```

	@param amount number
	@param unit UnitLike
	@return MetricUnit
]=]
function MetricUnit.difference(amount: number, unit: UnitLike): MetricUnit
	local definition = MetricUnit._definitionFor(amount, unit, "difference", 3)
	return MetricUnit._new(
		amount * definition.factor,
		definition.dimensions,
		false,
		MetricUnit._displayOfUnit(definition)
	)
end
--[=[
	A dimensionless value.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.none(n: number): MetricUnit
	MetricUnit._assertNumber(n, "none")
	return MetricUnit._new(n, MetricUnitDimensionUtils.NONE, false)
end

--[=[
	`n` milliseconds.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.milliseconds(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "millisecond", "milliseconds")
end

--[=[
	`n` seconds.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.seconds(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "second", "seconds")
end

--[=[
	`n` minutes.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.minutes(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "minute", "minutes")
end

--[=[
	`n` hours.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.hours(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "hour", "hours")
end

--[=[
	`n` days of 24 hours.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.days(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "day", "days")
end

--[=[
	`n` weeks of seven days.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.weeks(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "week", "weeks")
end

--[=[
	`n` averaged months, each exactly a twelfth of an averaged year. For calendar months, use `Time.add`.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.months(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "month", "months")
end

--[=[
	`n` averaged years of 365.25 days (a Julian year), for long-range elapsed time. For calendar years, use `Time.add`.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.years(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "year", "years")
end

--[=[
	`n` times a second.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.perSecond(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "perSecond", "perSecond")
end

--[=[
	`n` times an hour.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.perHour(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "perHour", "perHour")
end

--[=[
	`n` times a day.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.perDay(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "perDay", "perDay")
end

--[=[
	`n` times a year.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.perYear(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "perYear", "perYear")
end

--[=[
	`n` millimetres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.millimeters(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "millimeter", "millimeters")
end

--[=[
	`n` metres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.meters(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "meter", "meters")
end

--[=[
	`n` kilometres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kilometers(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kilometer", "kilometers")
end

--[=[
	`n` Roblox studs, 28 cm each, as Roblox measures them against the default avatar. For studs at a game's own
	scale, use its system: `MINI:New(n, "stud")`.

	```lua
	MetricUnit.studs(10):In("meter") -- 2.8
	```

	@param n number
	@return MetricUnit
]=]
function MetricUnit.studs(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "stud", "studs")
end
--[=[
	`n` square kilometres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.squareKilometers(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "squareKilometer", "squareKilometers")
end

--[=[
	`n` grams.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.grams(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "gram", "grams")
end

--[=[
	`n` kilograms.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kilograms(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kilogram", "kilograms")
end

--[=[
	`n` tonnes of 1,000 kg.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.tonnes(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "tonne", "tonnes")
end

--[=[
	`n` bytes.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.bytes(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "byte", "bytes")
end

--[=[
	`n` kilobytes of 1,000 bytes.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kilobytes(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kilobyte", "kilobytes")
end

--[=[
	`n` megabytes of 1,000,000 bytes.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.megabytes(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "megabyte", "megabytes")
end

--[=[
	`n` degrees, a 360th of a revolution.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.degrees(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "degree", "degrees")
end

--[=[
	`n` radians, the unit `CFrame.Angles` and `math.sin` take.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.radians(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "radian", "radians")
end

--[=[
	`n` percent, a hundredth each: `percent(45)` is 0.45.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.percent(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "percent", "percent")
end

--[=[
	The absolute temperature `n` kelvin.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kelvin(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kelvin", "kelvin")
end

--[=[
	The absolute temperature `n` °C.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.celsius(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "celsius", "celsius")
end

--[=[
	The absolute temperature `n` °F.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.fahrenheit(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "fahrenheit", "fahrenheit")
end

--[=[
	The instant `seconds` after an epoch: a point in time rather than a span of it. The epoch is whatever the caller
	measures from, such as a simulation's start; [MetricUnit.fromDateTime] uses the Unix epoch. Instants follow the
	same rules as absolute temperatures: two subtract to a span, an instant and a span add to an instant, and an
	instant cannot be added to another, scaled or negated. Instants from different epochs must not be mixed; nothing
	can check that for you.

	```lua
	local worldStart = MetricUnit.instant(0)
	local now = worldStart + MetricUnit.years(250)
	(now - worldStart):In("year") -- 250
	now:In("year") -- 250, time since its epoch
	```

	@param seconds number -- since the epoch
	@return MetricUnit
]=]
function MetricUnit.instant(seconds: number): MetricUnit
	MetricUnit._assertNumber(seconds, "instant")
	return MetricUnit._new(seconds, MetricUnitKinds.TIME, true)
end

--[=[
	The instant `dateTime` marks, measured from the Unix epoch, to the millisecond. Subtract two for the exact time
	between them, which counts calendar months and leap days at their real length.

	```lua
	local played = MetricUnit.fromDateTime(DateTime.now()) - MetricUnit.fromDateTime(joinedAt)
	```

	@param dateTime DateTime
	@return MetricUnit
]=]
function MetricUnit.fromDateTime(dateTime: DateTime): MetricUnit
	if typeof(dateTime) ~= "DateTime" then
		error(string.format("MetricUnit.fromDateTime takes a DateTime, not %s", typeof(dateTime)), 2)
	end
	return MetricUnit._new(dateTime.UnixTimestampMillis / 1000, MetricUnitKinds.TIME, true)
end

--[=[
	The speed of a Roblox velocity, such as `part.AssemblyLinearVelocity`, in studs per second by its magnitude. The
	value converts to metric through the stud like any other: read it with `:In("kilometerPerHour")`.

	@param velocity Vector3 -- in studs per second
	@return MetricUnit
]=]
function MetricUnit.fromStudVelocity(velocity: Vector3): MetricUnit
	if typeof(velocity) ~= "Vector3" then
		error(string.format("MetricUnit.fromStudVelocity takes a Vector3, not %s", typeof(velocity)), 2)
	end
	return MetricUnit.new(velocity.Magnitude, "studPerSecond")
end
--[=[
	Reads `text` such as `"5 km"`, `"2.5 kilometers"`, `"1h30m"`, `"1:30:00"`, `"20 °C"`, `"60 mph"` or `"5 m/s"`,
	for commands, admin tools, configs and text boxes. Returns nil and a message to show instead of erroring. See
	[MetricUnitParseUtils.parse] for the grammar and how `kind` resolves ambiguous text such as `"m"`.

	```lua
	local reach, err = MetricUnit.parse(textBox.Text, "length")
	if not reach then
		warn(err)
	end
	```

	@param text string
	@param kind (KindName | Dimensions)?
	@param options ParseOptions?
	@return MetricUnit?
	@return string? -- why it could not be read
]=]
function MetricUnit.parse(
	text: string,
	kind: (KindName | Dimensions)?,
	options: MetricUnitParseUtils.ParseOptions?
): (MetricUnit?, string?)
	return MetricUnit._parseInSystem(text, kind, options, nil)
end

function MetricUnit._parseInSystem(
	text: string,
	kind: (KindName | Dimensions)?,
	options: MetricUnitParseUtils.ParseOptions?,
	system: System?
): (MetricUnit?, string?)
	local data, err = MetricUnitParseUtils._parseInSystem(text, kind, options, system)
	if not data then
		return nil, err
	end
	local value = MetricUnit.fromData(data)
	return if system then value:ToSystem(system) else value, nil
end

--[=[
	Whether `value` is a [MetricUnit].

	@param value any
	@return boolean
]=]
function MetricUnit.isUnit(value: any): boolean
	return type(value) == "table" and getmetatable(value) == MetricUnit
end

--[=[
	Whether `value` is a [MetricUnit] of `kind`, a [KindName] or a table of exponents. Safe to call on anything.
	Errors on an unknown name, so a typo does not quietly answer false.

	```lua
	MetricUnit.isKind(MetricUnit.kilometers(1) / MetricUnit.hours(1), "speed") -- true
	MetricUnit.isKind(MetricUnit.celsius(5), "temperature") -- true, absolute
	MetricUnit.isKind(MetricUnit.difference(5, "celsius"), "temperatureDifference") -- true
	MetricUnit.isKind(5, "length") -- false
	```

	@param value any
	@param kind KindName | Dimensions
	@return boolean
]=]
function MetricUnit.isKind(value: any, kind: KindName | Dimensions): boolean
	local dimensions, absolute = MetricUnitKinds.fromName(kind)
	return MetricUnit.isUnit(value)
		and value._absolute == absolute
		and MetricUnitDimensionUtils.equal(value._dimensions, dimensions)
end

--[=[
	Whether `a` and `b` have the same dimensions; a plain 0 has every dimension and any other number none.

	@param a MetricUnit | number
	@param b MetricUnit | number
	@return boolean
]=]
function MetricUnit.sameDimension(a: MetricUnit | number, b: MetricUnit | number): boolean
	if a == 0 or b == 0 then
		return true
	end
	return MetricUnitDimensionUtils.equal(MetricUnit._dimensionsOf(a), MetricUnit._dimensionsOf(b))
end

--[=[
	The amount of `value` in SI base units, for checking arguments at an API boundary. Errors with `slot`, the
	dimension expected and the one given if `value` is not of `kind`. A plain 0 is zero of any kind but an absolute
	one.

	```lua
	local function setReach(reach: MetricUnit.MetricUnit | number)
		local meters = MetricUnit.expect(reach, "length", "reach")
	end
	```

	@param value MetricUnit | number
	@param kind KindName | Dimensions
	@param slot string -- what the value is for, used in the error
	@return number -- in SI base units
]=]
function MetricUnit.expect(value: MetricUnit | number, kind: KindName | Dimensions, slot: string): number
	local dimensions, absolute = MetricUnitKinds.fromName(kind)
	if type(value) == "number" then
		if value == 0 and not absolute then
			return 0
		elseif not absolute and next(dimensions) == nil then
			return value
		end
		error(
			string.format(
				"MetricUnit.expect: %s expects %s, got the plain number %s",
				slot,
				MetricUnitKinds.describeKind(dimensions, absolute),
				tostring(value)
			),
			2
		)
	end
	if not MetricUnit.isUnit(value) then
		error(
			string.format(
				"MetricUnit.expect: %s expects %s, got %s",
				slot,
				MetricUnitKinds.describeKind(dimensions, absolute),
				typeof(value)
			),
			2
		)
	end
	local unit = value :: MetricUnit
	if unit._absolute ~= absolute or not MetricUnitDimensionUtils.equal(unit._dimensions, dimensions) then
		error(
			string.format(
				"MetricUnit.expect: %s expects %s, got %s",
				slot,
				MetricUnitKinds.describeKind(dimensions, absolute),
				MetricUnitKinds.describeKind(unit._dimensions, unit._absolute)
			),
			2
		)
	end
	return unit._amount
end

--[=[
	Whether `value` is zero.

	@param value MetricUnit | number
	@return boolean
]=]
function MetricUnit.isZero(value: MetricUnit | number): boolean
	if type(value) == "number" then
		return value == 0
	end
	MetricUnit._assertUnit(value, "isZero")
	return value._amount == 0
end

--[=[
	-1, 0 or 1 as `value` is negative, zero or positive; an absolute temperature is measured from absolute zero.

	@param value MetricUnit | number
	@return number
]=]
function MetricUnit.sign(value: MetricUnit | number): number
	if type(value) == "number" then
		return math.sign(value)
	end
	MetricUnit._assertUnit(value, "sign")
	return math.sign(value._amount)
end

--[=[
	How many of `unit` this is. `unit` is a unit id, any of `@quenty/time`'s names for a time unit, or another
	[MetricUnit] to take the ratio with. Errors, naming both dimensions, when they differ.

	A point reads from the unit's zero, so a temperature reads on its scale and an instant as the time since its
	epoch; a difference reads as it is. Rates read per a time unit with the `per` ids.

	```lua
	MetricUnit.kilometers(2):In("meter") -- 2000
	MetricUnit.minutes(90):In("hours") -- 1.5
	MetricUnit.perDay(48):In("perHour") -- 2
	MetricUnit.celsius(100):In("fahrenheit") -- 212
	(MetricUnit.meters(10) / MetricUnit.seconds(1)):In(MetricUnit.kilometers(1) / MetricUnit.hours(1)) -- 36
	```

	@param unit UnitLike | MetricUnit
	@return number
]=]
function MetricUnit.In(self: MetricUnit, unit: UnitLike | MetricUnit): number
	MetricUnit._assertUnit(self, "In")
	if not MetricUnit.isUnit(unit) then
		local definition = MetricUnit._getUnit(unit :: UnitLike)
		if not definition then
			error(string.format("MetricUnit:In knows no unit %q", tostring(unit)), 2)
		end
		return MetricUnit._readUnit(self, definition)
	end

	MetricUnit._assertUnit(unit, "In")
	local other = unit :: MetricUnit
	MetricUnit._assertDifference(self, "take the ratio of")
	MetricUnit._assertDifference(other, "take the ratio of")
	if not MetricUnitDimensionUtils.equal(self._dimensions, other._dimensions) then
		error(
			string.format(
				"MetricUnit:In cannot read %s in %s",
				MetricUnitDimensionUtils.describe(self._dimensions),
				MetricUnitDimensionUtils.describe(other._dimensions)
			),
			2
		)
	end
	return self._amount / other._amount
end

--[=[
	This time in exact seconds, the same as `:In("second")`: the number to hand to `task.wait`, `os.time` arithmetic
	or `TimeDurationUtils`.

	```lua
	task.wait(MetricUnit.minutes(2):InSeconds())
	TimeDurationUtils.format(MetricUnit.hours(36):InSeconds(), "h:mm") --> 36:00
	```

	@return number
]=]
function MetricUnit.InSeconds(self: MetricUnit): number
	MetricUnit._assertUnit(self, "InSeconds")
	return MetricUnit._readUnit(self, (assert(MetricUnitDefinitions.getUnit("second"), "No second")))
end

--[=[
	This instant as a `DateTime`, to the nearest millisecond, taking its epoch to be the Unix epoch as
	[MetricUnit.fromDateTime] does. Errors on anything but an instant. To move a date by exact time, add a span:
	`(MetricUnit.fromDateTime(dateTime) + MetricUnit.days(7)):ToDateTime()`. To move by calendar months, use
	`Time.add` from `@quenty/time`.

	@return DateTime
]=]
function MetricUnit.ToDateTime(self: MetricUnit): DateTime
	MetricUnit._assertUnit(self, "ToDateTime")
	if not (self._absolute and MetricUnitDimensionUtils.equal(self._dimensions, MetricUnitKinds.TIME)) then
		error(
			string.format(
				"MetricUnit:ToDateTime takes an instant, not %s",
				MetricUnitKinds.describeKind(self._dimensions, self._absolute)
			),
			2
		)
	end
	local seconds = self._amount
	return DateTime.fromUnixTimestampMillis(math.floor(seconds * 1000 + 0.5))
end

--[=[
	This value's amount in SI base units: seconds, metres, kilograms, bytes, kelvin, or their products.

	@return number
]=]
function MetricUnit.GetBaseAmount(self: MetricUnit): number
	return self._amount
end

--[=[
	This value's frozen dimension exponents, such as `{ length = 1, time = -1 }` for a speed.

	@return Dimensions
]=]
function MetricUnit.GetDimensions(self: MetricUnit): Dimensions
	return self._dimensions
end

--[=[
	What this value measures, such as `"length"`, `"speed"` or `"temperature"`, or nil for a compound without a
	name, such as length to the fourth.

	@return KindName?
]=]
function MetricUnit.GetKind(self: MetricUnit): KindName?
	return MetricUnitKinds.getKind(self._dimensions, self._absolute)
end

--[=[
	Whether this value is of `kind`, a [KindName] or a table of exponents.

	@param kind KindName | Dimensions
	@return boolean
]=]
function MetricUnit.IsKind(self: MetricUnit, kind: KindName | Dimensions): boolean
	return MetricUnit.isKind(self, kind)
end

--[=[
	Whether this value is absolute, a point on a scale such as a temperature, rather than a difference.

	@return boolean
]=]
function MetricUnit.IsAbsolute(self: MetricUnit): boolean
	return self._absolute
end

--[=[
	The ids of every unit this value can be read in or formatted as, for a settings menu to offer. Metric units come
	first, then US customary ones, then Roblox studs.

	```lua
	MetricUnit.meters(1):GetUnitIds() -- { "millimeter", "centimeter", "meter", "kilometer", "inch", ... }
	```

	@return { UnitId }
]=]
function MetricUnit.GetUnitIds(self: MetricUnit): { UnitId }
	return MetricUnitDefinitions.getUnitIds(self._dimensions)
end

--[=[
	This value, preferring United States customary units when it is formatted: miles, feet and inches; US gallons,
	quarts and cups; short tons, pounds and ounces; mph, mpg (US), BTU, horsepower, psi and °F where its dimension
	has them, and metric units elsewhere. The amount is unchanged, so arithmetic, comparison, [MetricUnit.In] and
	saving behave exactly as before. A locale never chooses these units, not even `en-us`: call this from a
	player's setting.

	```lua
	MetricUnit.format(MetricUnit.kilometers(5):ToUSCustomary()) --> 3.107 mi
	MetricUnit.format(MetricUnit.new(2, "liter"):ToUSCustomary()) --> 2.113 qt
	local shown = if settings.useImperial then distance:ToUSCustomary() else distance
	```

	@return MetricUnit
]=]
function MetricUnit.ToUSCustomary(self: MetricUnit): MetricUnit
	return MetricUnit.ToSystem(self, MetricUnitSystems.US_CUSTOMARY)
end
--[=[
	This value, preferring British imperial units when it is formatted: imperial gallons, pints and fluid ounces;
	stone, pounds and ounces; mpg (UK); and the units Britain shares with the United States (miles, mph, BTU,
	horsepower, psi, °F). The amount is unchanged. See [MetricUnit.ToUSCustomary] for US units.

	```lua
	MetricUnit.format(MetricUnit.new(2, "liter"):ToImperial()) --> 3.52 imp pt
	MetricUnit.format(MetricUnit.kilograms(80):ToImperial()) --> 12.598 st
	```

	@return MetricUnit
]=]
function MetricUnit.ToImperial(self: MetricUnit): MetricUnit
	return MetricUnit.ToSystem(self, MetricUnitSystems.IMPERIAL)
end
--[=[
	This value, preferring metric units when it is formatted. Metric is already the default; this clears a US
	customary or imperial preference or a pinned unit.

	@return MetricUnit
]=]
function MetricUnit.ToMetric(self: MetricUnit): MetricUnit
	return MetricUnit.ToSystem(self, MetricUnitSystems.METRIC)
end

--[=[
	This value, preferring `system`'s units when it is formatted. The amount is unchanged, so arithmetic,
	comparison, [MetricUnit.In] and saving behave exactly as before. [MetricUnit.ToUSCustomary],
	[MetricUnit.ToImperial] and [MetricUnit.ToMetric] are this with the well-known systems.

	```lua
	MetricUnit.format(MetricUnit.meters(0.14):ToSystem(MINI)) --> 5 studs, in a game's own system
	```

	@param system MetricUnitSystem
	@return MetricUnit
]=]
function MetricUnit.ToSystem(self: MetricUnit, system: System): MetricUnit
	MetricUnit._assertUnit(self, "ToSystem")
	if not MetricUnitSystem.isSystem(system) then
		error(string.format("MetricUnit:ToSystem takes a MetricUnitSystem, not %s", typeof(system)), 2)
	end
	return MetricUnit._new(self._amount, self._dimensions, self._absolute, table.freeze({ system = system }))
end
--[=[
	This value, always formatted in `unit`, which must measure the same thing. The amount is unchanged.

	```lua
	MetricUnit.format(MetricUnit.kilometers(5):As("mile")) --> 3.107 mi
	MetricUnit.format(MetricUnit.meters(28):As("stud")) --> 100 studs
	MetricUnit.format(height:As(MINI:GetUnit("stud"))) --> a game's own stud
	```

	@param unit UnitLike
	@return MetricUnit
]=]
function MetricUnit.As(self: MetricUnit, unit: UnitLike): MetricUnit
	MetricUnit._assertUnit(self, "As")
	local definition = MetricUnit._getUnit(unit)
	if not definition then
		error(string.format("MetricUnit:As knows no unit %q", tostring(unit)), 2)
	elseif not MetricUnitDimensionUtils.equal(definition.dimensions, self._dimensions) then
		error(
			string.format(
				"MetricUnit:As(%q) is %s, not %s",
				definition.id,
				MetricUnitDimensionUtils.describe(definition.dimensions),
				MetricUnitKinds.describeKind(self._dimensions, self._absolute)
			),
			2
		)
	end
	local display = table.freeze({
		system = MetricUnitSystems.getSystemOfUnit(definition),
		unit = definition,
	})
	return MetricUnit._new(self._amount, self._dimensions, self._absolute, display)
end

--[=[
	The system this value prefers to be formatted in, from [MetricUnit.ToSystem] or [MetricUnit.As], or nil for the
	default (metric). A display concern only: it is not saved by [MetricUnit.toData] and never affects arithmetic.

	@return MetricUnitSystem?
]=]
function MetricUnit.GetDisplaySystem(self: MetricUnit): System?
	local display = self._display
	return if display then display.system else nil
end

--[=[
	The unit this value is always formatted in, from [MetricUnit.As], or nil.

	@return UnitDefinition?
]=]
function MetricUnit.GetDisplayUnit(self: MetricUnit): MetricUnitDefinitions.UnitDefinition?
	local display = self._display
	return if display then display.unit else nil
end

--[=[
	Text for players, localized, in a unit that suits the size. See [MetricUnitFormatUtils.format] for the options.
	An instant is written as the time since its epoch, since only the caller knows what the epoch is; for a calendar
	date, use `Time.format(x:ToDateTime(), ...)` from `@quenty/time`.

	```lua
	MetricUnit.format(MetricUnit.meters(2500)) --> 2.5 km
	MetricUnit.format(MetricUnit.meters(2500), { unitDisplay = "long", locale = "en-gb" }) --> 2.5 kilometres
	MetricUnit.format(MetricUnit.new(90, "kilometerPerHour"), { unit = "kilometerPerHour" }) --> 90 km/h
	MetricUnit.format(MetricUnit.kilometers(5):ToUSCustomary()) --> 3.107 mi
	MetricUnit.format(MetricUnit.years(1)) --> 1 year
	MetricUnit.format(MetricUnit.minutes(90), { locale = "es-es" }) --> 1 hora, 30 minutos
	```

	@param value MetricUnit
	@param options FormatOptions?
	@return string
]=]
function MetricUnit.format(value: MetricUnit, options: FormatOptions?): string
	MetricUnit._assertUnit(value, "format")
	return MetricUnitFormatUtils.format(value, options)
end

--[=[
	`value` as plain data, for saves.

	@param value MetricUnit
	@return MetricUnitData
]=]
function MetricUnit.toData(value: MetricUnit): MetricUnitData
	MetricUnit._assertUnit(value, "toData")
	return {
		amount = value._amount,
		dimensions = table.clone(value._dimensions),
		absolute = if value._absolute then true else nil,
	}
end

--[=[
	The [MetricUnit] that `data` from [MetricUnit.toData] holds.

	@param data MetricUnitData
	@return MetricUnit
]=]
function MetricUnit.fromData(data: MetricUnitData): MetricUnit
	if
		type(data) ~= "table"
		or type(data.amount) ~= "number"
		or not MetricUnitDimensionUtils.isDimensions(data.dimensions)
	then
		error("MetricUnit.fromData takes { amount: number, dimensions: { [string]: integer }, absolute: boolean? }", 2)
	end
	return MetricUnit._new(data.amount, table.freeze(table.clone(data.dimensions)), data.absolute == true)
end

--[=[
	The size of `value`, a difference.

	@param value MetricUnit
	@return MetricUnit
]=]
function MetricUnit.abs(value: MetricUnit): MetricUnit
	MetricUnit._assertUnit(value, "abs")
	MetricUnit._assertDifference(value, "take the size of")
	return MetricUnit._new(math.abs(value._amount), value._dimensions, false, value._display)
end

--[=[
	The square root of `value`, halving its exponents, erroring if any is odd.

	@param value MetricUnit
	@return MetricUnit
]=]
function MetricUnit.sqrt(value: MetricUnit): MetricUnit
	MetricUnit._assertUnit(value, "sqrt")
	MetricUnit._assertDifference(value, "take the square root of")
	if value._amount < 0 then
		error(
			string.format("MetricUnit.sqrt of a negative %s", MetricUnitDimensionUtils.describe(value._dimensions)),
			2
		)
	end
	return MetricUnit._new(
		math.sqrt(value._amount),
		MetricUnitDimensionUtils.scale(value._dimensions, 0.5),
		false,
		MetricUnit._systemOnly(value._display)
	)
end

--[=[
	`value` to the whole power `power`, multiplying its exponents.

	@param value MetricUnit
	@param power number -- a whole number
	@return MetricUnit
]=]
function MetricUnit.pow(value: MetricUnit, power: number): MetricUnit
	MetricUnit._assertUnit(value, "pow")
	MetricUnit._assertDifference(value, "exponentiate")
	if type(power) ~= "number" or power ~= math.floor(power) then
		error(string.format("MetricUnit.pow takes a whole power, not %s", tostring(power)), 2)
	end
	return MetricUnit._new(
		value._amount ^ power,
		MetricUnitDimensionUtils.scale(value._dimensions, power),
		false,
		MetricUnit._systemOnly(value._display)
	)
end

--[=[
	`value` rounded to a whole number of `step`, halves rounding up. `step` is a unit id, such as `"minute"`, or a
	value to snap to a multiple of. A temperature rounds on its own scale (`round(celsius(21.6), "celsius")` is
	22 °C) and an instant rounds from its epoch.

	```lua
	MetricUnit.round(MetricUnit.seconds(95), "minute") -- 2 minutes
	MetricUnit.round(MetricUnit.meters(12.4), MetricUnit.meters(5)) -- 10 m
	```

	@param value MetricUnit
	@param step UnitLike | MetricUnit
	@return MetricUnit
]=]
function MetricUnit.round(value: MetricUnit, step: UnitLike | MetricUnit): MetricUnit
	return MetricUnit._snap(value, step, function(count: number): number
		return math.floor(count + 0.5)
	end, "round")
end

--[=[
	`value` rounded down to a whole number of `step`. See [MetricUnit.round].

	@param value MetricUnit
	@param step UnitLike | MetricUnit
	@return MetricUnit
]=]
function MetricUnit.floor(value: MetricUnit, step: UnitLike | MetricUnit): MetricUnit
	return MetricUnit._snap(value, step, math.floor, "floor")
end

--[=[
	`value` rounded up to a whole number of `step`. See [MetricUnit.round].

	@param value MetricUnit
	@param step UnitLike | MetricUnit
	@return MetricUnit
]=]
function MetricUnit.ceil(value: MetricUnit, step: UnitLike | MetricUnit): MetricUnit
	return MetricUnit._snap(value, step, math.ceil, "ceil")
end

--[=[
	The smallest of `...`, all of one dimension.

	@param ... MetricUnit | number
	@return MetricUnit
]=]
function MetricUnit.min(...: MetricUnit | number): MetricUnit
	return MetricUnit._extreme("min", math.min, ...)
end

--[=[
	The largest of `...`, all of one dimension.

	@param ... MetricUnit | number
	@return MetricUnit
]=]
function MetricUnit.max(...: MetricUnit | number): MetricUnit
	return MetricUnit._extreme("max", math.max, ...)
end

--[=[
	`value` held between `low` and `high`, all of one dimension.

	@param value MetricUnit | number
	@param low MetricUnit | number
	@param high MetricUnit | number
	@return MetricUnit
]=]
function MetricUnit.clamp(value: MetricUnit | number, low: MetricUnit | number, high: MetricUnit | number): MetricUnit
	return MetricUnit.min(MetricUnit.max(value, low), high)
end

--[=[
	The value `t` of the way from `a` to `b`, of one dimension, for animation. Follows the absolute/difference rules,
	so lerping two temperatures or two instants gives a temperature or an instant.

	@param a MetricUnit | number
	@param b MetricUnit | number
	@param t number -- 0 gives `a`, 1 gives `b`
	@return MetricUnit
]=]
function MetricUnit.lerp(a: MetricUnit | number, b: MetricUnit | number, t: number): MetricUnit
	if type(t) ~= "number" then
		error(string.format("MetricUnit.lerp takes a number t, not %s", typeof(t)), 2)
	end
	return ((a :: any) + ((b :: any) - (a :: any)) * t) :: MetricUnit
end

--[=[
	The sum of `values`, all of one dimension. Absolutes cannot be summed, as with `+`.

	@param values { MetricUnit | number }
	@return MetricUnit
]=]
function MetricUnit.sum(values: { MetricUnit | number }): MetricUnit
	if type(values) ~= "table" or #values == 0 then
		error("MetricUnit.sum takes a list of at least one value", 2)
	end
	local total: any = values[1]
	for index = 2, #values do
		total += values[index]
	end
	if type(total) == "number" then
		return MetricUnit.none(total)
	end
	return total
end

--[=[
	The mean of `values`, all of one dimension. Absolutes average too: the mean of two temperatures is the
	temperature halfway between them. For the smallest or largest of a list, use
	`MetricUnit.min(table.unpack(values))`.

	@param values { MetricUnit | number }
	@return MetricUnit
]=]
function MetricUnit.mean(values: { MetricUnit | number }): MetricUnit
	if type(values) ~= "table" or #values == 0 then
		error("MetricUnit.mean takes a list of at least one value", 2)
	end
	local first: any = values[1]
	local sumOfDifferencesFromFirst: any = 0
	for index = 2, #values do
		sumOfDifferencesFromFirst += (values[index] :: any) - first
	end
	local result: any = first + sumOfDifferencesFromFirst / #values
	if type(result) == "number" then
		return MetricUnit.none(result)
	end
	return result
end

--[=[
	Whether `a` and `b`, of one dimension, are within `epsilon` of each other. `epsilon` is a [MetricUnit] of their
	dimension, or a plain number in SI base units (1e-9 by default).

	@param a MetricUnit | number
	@param b MetricUnit | number
	@param epsilon (MetricUnit | number)?
	@return boolean
]=]
function MetricUnit.fuzzyEq(a: MetricUnit | number, b: MetricUnit | number, epsilon: (MetricUnit | number)?): boolean
	local aAmount, bAmount, dimensions = MetricUnit._pair(a, b, "compare")
	local tolerance = 1e-9
	if epsilon ~= nil then
		if type(epsilon) == "number" then
			tolerance = epsilon
		else
			tolerance = MetricUnit.expect(epsilon, dimensions, "fuzzyEq's epsilon")
		end
	end
	return math.abs(aAmount - bAmount) <= tolerance
end

--[=[
	The length an angle sweeps along a circle of `radius`, or, for an angular velocity, the speed along it.
	Angles never mix with lengths on their own, so this is the one place they meet.

	```lua
	MetricUnit.arcLength(MetricUnit.degrees(180), MetricUnit.meters(2)):In("meter") -- 6.283
	MetricUnit.arcLength(MetricUnit.new(60, "revolutionPerMinute"), MetricUnit.meters(1)):In("meterPerSecond") -- 6.283
	```

	@param angular MetricUnit -- an angle, or an angle per time
	@param radius MetricUnit -- a length
	@return MetricUnit
]=]
function MetricUnit.arcLength(angular: MetricUnit, radius: MetricUnit): MetricUnit
	MetricUnit._assertUnit(angular, "arcLength")
	MetricUnit._assertDifference(angular, "take the arc length of")
	if angular._dimensions.angle ~= 1 then
		error(
			string.format(
				"MetricUnit.arcLength takes an angle or an angle per time, not %s",
				MetricUnitDimensionUtils.describe(angular._dimensions)
			),
			2
		)
	end
	local meters = MetricUnit.expect(radius, "length", "arcLength's radius")
	local dimensions = MetricUnitDimensionUtils.combine(
		MetricUnitDimensionUtils.combine(angular._dimensions, MetricUnitKinds.ANGLE, -1),
		MetricUnitKinds.LENGTH,
		1
	)
	return MetricUnit._new(
		angular._amount * meters,
		dimensions,
		false,
		MetricUnit._systemOnly(MetricUnit._displayOf(radius))
	)
end

--[=[
	The sum of two values of one dimension; an absolute and a difference give an absolute.

	@param a MetricUnit | number
	@param b MetricUnit | number
	@return MetricUnit
]=]
function MetricUnit.__add(a: MetricUnit | number, b: MetricUnit | number): MetricUnit
	local aAmount, bAmount, dimensions, aAbsolute, bAbsolute = MetricUnit._pair(a, b, "add")
	if aAbsolute and bAbsolute then
		error(
			string.format(
				"MetricUnit: cannot add two %ss; subtract them for a difference, or add a difference to one",
				MetricUnitKinds.describeKind(dimensions, true)
			),
			2
		)
	end
	local display = MetricUnit._mergeDisplay(MetricUnit._displayOf(a), MetricUnit._displayOf(b))
	return MetricUnit._new(aAmount + bAmount, dimensions, aAbsolute or bAbsolute, display)
end

--[=[
	The difference of two values of one dimension; two absolutes give a difference.

	@param a MetricUnit | number
	@param b MetricUnit | number
	@return MetricUnit
]=]
function MetricUnit.__sub(a: MetricUnit | number, b: MetricUnit | number): MetricUnit
	local aAmount, bAmount, dimensions, aAbsolute, bAbsolute = MetricUnit._pair(a, b, "subtract")
	if bAbsolute and not aAbsolute then
		error(
			string.format(
				"MetricUnit: cannot subtract an %s from a %s",
				MetricUnitKinds.describeKind(dimensions, true),
				MetricUnitKinds.describeKind(dimensions, false)
			),
			2
		)
	end
	local display = MetricUnit._mergeDisplay(MetricUnit._displayOf(a), MetricUnit._displayOf(b))
	return MetricUnit._new(aAmount - bAmount, dimensions, aAbsolute and not bAbsolute, display)
end

--[=[
	The product, combining dimensions; a plain number scales.

	@param a MetricUnit | number
	@param b MetricUnit | number
	@return MetricUnit
]=]
function MetricUnit.__mul(a: MetricUnit | number, b: MetricUnit | number): MetricUnit
	local aAmount, aDimensions = MetricUnit._scalable(a, "multiply")
	local bAmount, bDimensions = MetricUnit._scalable(b, "multiply")
	local display = MetricUnit._productDisplay(a, b)
	return MetricUnit._new(
		aAmount * bAmount,
		MetricUnitDimensionUtils.combine(aDimensions, bDimensions, 1),
		false,
		display
	)
end

--[=[
	The quotient, combining dimensions; a plain number scales, or over a unit inverts it.

	@param a MetricUnit | number
	@param b MetricUnit | number
	@return MetricUnit
]=]
function MetricUnit.__div(a: MetricUnit | number, b: MetricUnit | number): MetricUnit
	local aAmount, aDimensions = MetricUnit._scalable(a, "divide")
	local bAmount, bDimensions = MetricUnit._scalable(b, "divide")
	local display = MetricUnit._quotientDisplay(a, b)
	return MetricUnit._new(
		aAmount / bAmount,
		MetricUnitDimensionUtils.combine(aDimensions, bDimensions, -1),
		false,
		display
	)
end

--[=[
	The negation of a difference.

	@param a MetricUnit
	@return MetricUnit
]=]
function MetricUnit.__unm(a: MetricUnit): MetricUnit
	MetricUnit._assertDifference(a, "negate")
	return MetricUnit._new(-a._amount, a._dimensions, false, a._display)
end

--[=[
	Whether `a` equals `b`, both of one kind.

	@param a MetricUnit
	@param b MetricUnit
	@return boolean
]=]
function MetricUnit.__eq(a: MetricUnit, b: MetricUnit): boolean
	local aAmount, bAmount = MetricUnit._pair(a, b, "compare")
	return aAmount == bAmount
end

--[=[
	Whether `a` is less than `b`, both of one kind.

	@param a MetricUnit
	@param b MetricUnit
	@return boolean
]=]
function MetricUnit.__lt(a: MetricUnit, b: MetricUnit): boolean
	local aAmount, bAmount = MetricUnit._pair(a, b, "compare")
	return aAmount < bAmount
end

--[=[
	Whether `a` is at most `b`, both of one kind.

	@param a MetricUnit
	@param b MetricUnit
	@return boolean
]=]
function MetricUnit.__le(a: MetricUnit, b: MetricUnit): boolean
	local aAmount, bAmount = MetricUnit._pair(a, b, "compare")
	return aAmount <= bAmount
end

--[=[
	[MetricUnit.format] in English with four significant digits, the same in every locale, for logs and test failures.
	An instant is written as its time since the epoch, such as "epoch + 1 minute, 30 seconds".

	@return string
]=]
function MetricUnit.__tostring(self: MetricUnit): string
	local text = MetricUnitFormatUtils.format(self, TOSTRING_FORMAT_OPTIONS)
	if self._absolute and MetricUnitDimensionUtils.equal(self._dimensions, MetricUnitKinds.TIME) then
		return "epoch + " .. text
	end
	return text
end

function MetricUnit._new(
	amount: number,
	dimensions: Dimensions,
	absolute: boolean,
	display: DisplayPreference?
): MetricUnit
	local unit: MetricUnit = setmetatable({} :: any, MetricUnit)
	unit._amount = amount
	unit._dimensions = dimensions
	unit._absolute = absolute
	unit._display = display
	table.freeze(unit :: any)
	return unit
end
function MetricUnit._fromUnit(n: number, unit: string | MetricUnitDefinitions.UnitDefinition, name: string): MetricUnit
	local definition = MetricUnit._definitionFor(n, unit, name, 4)
	local display = MetricUnit._displayOfUnit(definition)
	local scaleZero = definition.zero
	if scaleZero ~= nil then
		return MetricUnit._new(n * definition.factor + scaleZero, definition.dimensions, true, display)
	end
	return MetricUnit._new(n * definition.factor, definition.dimensions, false, display)
end

function MetricUnit._displayOfUnit(definition: MetricUnitDefinitions.UnitDefinition): DisplayPreference?
	local system = MetricUnitSystems.getSystemOfUnit(definition)
	if system == nil or rawequal(system, MetricUnitSystems.METRIC) then
		return nil
	end
	return table.freeze({ system = system })
end

function MetricUnit._getUnit(
	unit: string | MetricUnitDefinitions.UnitDefinition,
	system: System?
): MetricUnitDefinitions.UnitDefinition?
	if system ~= nil and not MetricUnitSystem.isSystem(system) then
		error(string.format("Bad system, expected a MetricUnitSystem, not %s", typeof(system)), 4)
	end
	return if system then system:GetUnit(unit) else MetricUnitDefinitions.getUnit(unit)
end
function MetricUnit._definitionFor(
	n: number,
	unit: any,
	name: string,
	errorLevel: number
): MetricUnitDefinitions.UnitDefinition
	if type(n) ~= "number" then
		error(string.format("MetricUnit.%s takes a number, not %s", name, typeof(n)), errorLevel)
	end
	local definition = MetricUnit._getUnit(unit)
	if not definition then
		error(string.format("MetricUnit.%s knows no unit %q", name, tostring(unit)), errorLevel)
	end
	return definition
end

function MetricUnit._assertNumber(n: any, name: string)
	if type(n) ~= "number" then
		error(string.format("MetricUnit.%s takes a number, not %s", name, typeof(n)), 4)
	end
end

function MetricUnit._assertUnit(value: any, name: string)
	if not MetricUnit.isUnit(value) then
		error(string.format("MetricUnit.%s takes a MetricUnit, not %s", name, typeof(value)), 4)
	end
end

function MetricUnit._assertDifference(value: MetricUnit, verb: string)
	if value._absolute then
		error(
			string.format(
				"MetricUnit: cannot %s an %s; subtract another to get a difference",
				verb,
				MetricUnitKinds.describeKind(value._dimensions, true)
			),
			4
		)
	end
end

function MetricUnit._readUnit(self: MetricUnit, definition: MetricUnitDefinitions.UnitDefinition): number
	if not MetricUnitDimensionUtils.equal(self._dimensions, definition.dimensions) then
		error(
			string.format(
				"MetricUnit:In(%q) reads %s, not %s",
				definition.id,
				MetricUnitDimensionUtils.describe(definition.dimensions),
				MetricUnitKinds.describeKind(self._dimensions, self._absolute)
			),
			3
		)
	end
	local fromZero = if self._absolute then self._amount - (definition.zero or 0) else self._amount
	return fromZero / definition.factor
end

function MetricUnit._snap(
	self: MetricUnit,
	step: UnitLike | MetricUnit,
	snap: (number) -> number,
	name: string
): MetricUnit
	MetricUnit._assertUnit(self, name)
	if not MetricUnit.isUnit(step) then
		local definition = MetricUnit._getUnit(step :: UnitLike, self:GetDisplaySystem())
		if not definition then
			error(string.format("MetricUnit.%s knows no unit %q", name, tostring(step)), 3)
		end
		local count = snap(MetricUnit._readUnit(self, definition))
		local amount = if self._absolute
			then count * definition.factor + (definition.zero or 0)
			else count * definition.factor
		return MetricUnit._new(amount, self._dimensions, self._absolute, self._display)
	end

	MetricUnit._assertUnit(step, name)
	local unit = step :: MetricUnit
	MetricUnit._assertDifference(unit, "round to")
	if not MetricUnitDimensionUtils.equal(unit._dimensions, self._dimensions) or unit._amount <= 0 then
		error(
			string.format(
				"MetricUnit.%s takes a positive step of %s, not %s",
				name,
				MetricUnitDimensionUtils.describe(self._dimensions),
				MetricUnitDimensionUtils.describe(unit._dimensions)
			),
			3
		)
	end
	local scaleZero = if self._absolute then MetricUnit._displayScaleZero(self) else 0
	return MetricUnit._new(
		snap((self._amount - scaleZero) / unit._amount) * unit._amount + scaleZero,
		self._dimensions,
		self._absolute,
		self._display
	)
end

function MetricUnit._displayScaleZero(self: MetricUnit): number
	local display = self._display
	local pinned = if display then display.unit else nil
	if pinned then
		return pinned.zero or 0
	end
	local units = MetricUnitDisplayUnitUtils.getDisplayUnits(self._dimensions, self:GetDisplaySystem(), true)
	local scale = if units then units[1] else nil
	return if scale and scale.zero then scale.zero else 0
end

function MetricUnit._dimensionsOf(value: MetricUnit | number): Dimensions
	if type(value) == "number" then
		return MetricUnitDimensionUtils.NONE
	end
	MetricUnit._assertUnit(value, "sameDimension")
	return value._dimensions
end

function MetricUnit._scalable(value: MetricUnit | number, verb: string): (number, Dimensions)
	if type(value) == "number" then
		return value, MetricUnitDimensionUtils.NONE
	end
	MetricUnit._assertUnit(value, verb)
	MetricUnit._assertDifference(value, verb)
	return value._amount, value._dimensions
end

function MetricUnit._pair(
	a: MetricUnit | number,
	b: MetricUnit | number,
	verb: string
): (number, number, Dimensions, boolean, boolean)
	if type(a) == "number" and type(b) == "number" then
		return a, b, MetricUnitDimensionUtils.NONE, false, false
	elseif type(a) == "number" then
		MetricUnit._assertUnit(b, verb)
		local unit = b :: MetricUnit
		return a, unit._amount, MetricUnit._numberDimensions(a, unit, verb), false, unit._absolute
	elseif type(b) == "number" then
		MetricUnit._assertUnit(a, verb)
		return a._amount, b, MetricUnit._numberDimensions(b, a, verb), a._absolute, false
	end
	MetricUnit._assertUnit(a, verb)
	MetricUnit._assertUnit(b, verb)
	if not MetricUnitDimensionUtils.equal(a._dimensions, b._dimensions) then
		error(
			string.format(
				"MetricUnit: cannot %s %s and %s",
				verb,
				MetricUnitKinds.describeKind(a._dimensions, a._absolute),
				MetricUnitKinds.describeKind(b._dimensions, b._absolute)
			),
			3
		)
	end
	if verb == "compare" and a._absolute ~= b._absolute then
		error(
			string.format(
				"MetricUnit: cannot compare an %s and a %s",
				MetricUnitKinds.describeKind(a._dimensions, true),
				MetricUnitKinds.describeKind(a._dimensions, false)
			),
			3
		)
	end
	return a._amount, b._amount, a._dimensions, a._absolute, b._absolute
end

function MetricUnit._numberDimensions(n: number, unit: MetricUnit, verb: string): Dimensions
	if n == 0 and not (verb == "compare" and unit._absolute) then
		return unit._dimensions
	elseif next(unit._dimensions) == nil and not unit._absolute then
		return unit._dimensions
	end
	error(
		string.format(
			"MetricUnit: cannot %s %s and the plain number %s",
			verb,
			MetricUnitKinds.describeKind(unit._dimensions, unit._absolute),
			tostring(n)
		),
		4
	)
end

function MetricUnit._extreme(name: string, pick: (number, number) -> number, ...: MetricUnit | number): MetricUnit
	local count = select("#", ...)
	if count == 0 then
		error(string.format("MetricUnit.%s takes at least one value", name), 3)
	end
	local reference: MetricUnit | number = 0
	for index = 1, count do
		local value = select(index, ...)
		if value ~= 0 then
			reference = value
			break
		end
	end
	local bestAmount, _, dimensions, absolute = MetricUnit._pair(select(1, ...), reference, "compare")
	local display = MetricUnit._displayOf(select(1, ...))
	for index = 2, count do
		local value = select(index, ...)
		local amount = MetricUnit._pair(value, reference, "compare")
		bestAmount = pick(bestAmount, amount)
		display = MetricUnit._mergeDisplay(display, MetricUnit._displayOf(value))
	end
	return MetricUnit._new(bestAmount, dimensions, absolute, display)
end

function MetricUnit._displayOf(value: any): DisplayPreference?
	return if MetricUnit.isUnit(value) then value._display else nil
end

function MetricUnit._mergeDisplay(a: DisplayPreference?, b: DisplayPreference?): DisplayPreference?
	if a == nil then
		return b
	elseif b == nil or (a.system == b.system and a.unit == b.unit) then
		return a
	end
	return MetricUnit._sharedSystem(a, b)
end

function MetricUnit._productDisplay(a: any, b: any): DisplayPreference?
	if type(b) == "number" then
		return MetricUnit._displayOf(a)
	elseif type(a) == "number" then
		return MetricUnit._displayOf(b)
	end
	return MetricUnit._newDimensionDisplay(a, b)
end

function MetricUnit._quotientDisplay(a: any, b: any): DisplayPreference?
	if type(b) == "number" then
		return MetricUnit._displayOf(a)
	end
	return MetricUnit._newDimensionDisplay(a, b)
end

function MetricUnit._newDimensionDisplay(a: any, b: any): DisplayPreference?
	local aDisplay = MetricUnit._systemOnly(MetricUnit._displayOf(a))
	local bDisplay = MetricUnit._systemOnly(MetricUnit._displayOf(b))
	if aDisplay == nil then
		return bDisplay
	elseif bDisplay == nil then
		return aDisplay
	end
	return MetricUnit._sharedSystem(aDisplay, bDisplay)
end

function MetricUnit._sharedSystem(a: DisplayPreference, b: DisplayPreference): DisplayPreference?
	return if a.system ~= nil and a.system == b.system then table.freeze({ system = a.system }) else nil
end

function MetricUnit._systemOnly(display: DisplayPreference?): DisplayPreference?
	local system = if display then display.system else nil
	return if system then table.freeze({ system = system }) else nil
end

return MetricUnit
