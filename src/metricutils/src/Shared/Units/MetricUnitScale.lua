--!strict
--[=[
	The size of each named unit in its dimension's SI base unit: seconds, metres, kilograms, bytes and kelvin. This
	is the one place unit sizes are defined; [MetricUnit], its formatter and [MetricUtils] all read them from here.

	Derived units are given in the matching product of the base units, so a newton is 1 (kg·m/s^2) and a
	kilowatt-hour is 3,600,000 (J). Memory uses decimal prefixes for kilobytes, megabytes and gigabytes
	(1 kB = 1,000 B) and binary ones for kibibytes, mebibytes and gibibytes (1 KiB = 1,024 B). US customary and
	imperial units use their exact definitions (an inch is 0.0254 m, a pound 0.45359237 kg). The offset temperature
	scales give their zero in kelvin.

	```lua
	MetricUnitScale.HOUR -- 3600, in seconds
	MetricUnitScale.YEAR -- 31557600, a Julian year of 365.25 days in seconds
	MetricUnitScale.STUD -- 1 / 3.57, in metres
	MetricUnitScale.POUND -- 0.45359237, in kilograms
	```

	@class MetricUnitScale
]=]

local MetricUnitScale = {}

-- Time, in seconds
MetricUnitScale.MICROSECOND = 1e-6
MetricUnitScale.MILLISECOND = 1e-3
MetricUnitScale.SECOND = 1
MetricUnitScale.MINUTE = 60
MetricUnitScale.HOUR = 3_600
MetricUnitScale.DAY = 86_400
MetricUnitScale.WEEK = 7 * 86_400
-- Elapsed-time averages for long-range math, not calendar spans: a Julian year with its leap day averaged in, and
-- a month of exactly a twelfth of it, so twelve months make a year. Calendar years and months, which vary in
-- length, belong to @quenty/time's Time.add.
MetricUnitScale.YEAR = 365.25 * 86_400
MetricUnitScale.MONTH = MetricUnitScale.YEAR / 12
MetricUnitScale.QUARTER = MetricUnitScale.YEAR / 4

-- Length, in metres
MetricUnitScale.MILLIMETER = 1e-3
MetricUnitScale.CENTIMETER = 1e-2
MetricUnitScale.METER = 1
MetricUnitScale.KILOMETER = 1_000
MetricUnitScale.INCH = 0.0254
MetricUnitScale.FOOT = 0.3048
MetricUnitScale.YARD = 0.9144
MetricUnitScale.MILE = 1_609.344
-- Roblox studs as MetricUtils has always counted them, 3.57 to the metre
MetricUnitScale.STUDS_PER_METER = 3.57
MetricUnitScale.STUD = 1 / MetricUnitScale.STUDS_PER_METER

-- Area, in square metres
MetricUnitScale.SQUARE_MILLIMETER = 1e-6
MetricUnitScale.SQUARE_CENTIMETER = 1e-4
MetricUnitScale.SQUARE_METER = 1
MetricUnitScale.HECTARE = 1e4
MetricUnitScale.SQUARE_KILOMETER = 1e6
MetricUnitScale.SQUARE_FOOT = 0.3048 * 0.3048
MetricUnitScale.ACRE = 4_046.8564224

-- Volume, in cubic metres
MetricUnitScale.MILLILITER = 1e-6
MetricUnitScale.LITER = 1e-3
MetricUnitScale.CUBIC_METER = 1
MetricUnitScale.US_GALLON = 3.785411784e-3
MetricUnitScale.US_FLUID_OUNCE = 3.785411784e-3 / 128
MetricUnitScale.IMPERIAL_GALLON = 4.54609e-3

-- Memory, in bytes
MetricUnitScale.BYTE = 1
MetricUnitScale.KILOBYTE = 1e3
MetricUnitScale.MEGABYTE = 1e6
MetricUnitScale.GIGABYTE = 1e9
MetricUnitScale.KIBIBYTE = 1_024
MetricUnitScale.MEBIBYTE = 1_024 ^ 2
MetricUnitScale.GIBIBYTE = 1_024 ^ 3

-- Mass, in kilograms
MetricUnitScale.MILLIGRAM = 1e-6
MetricUnitScale.GRAM = 1e-3
MetricUnitScale.KILOGRAM = 1
MetricUnitScale.TONNE = 1_000
MetricUnitScale.POUND = 0.45359237
MetricUnitScale.OUNCE = 0.45359237 / 16
MetricUnitScale.STONE = 0.45359237 * 14

-- Speed, in metres per second
MetricUnitScale.METER_PER_SECOND = 1
MetricUnitScale.KILOMETER_PER_HOUR = 1_000 / 3_600
MetricUnitScale.MILE_PER_HOUR = 1_609.344 / 3_600
MetricUnitScale.KNOT = 1_852 / 3_600
MetricUnitScale.STUD_PER_SECOND = MetricUnitScale.STUD

-- Acceleration, in metres per second squared
MetricUnitScale.METER_PER_SECOND_SQUARED = 1
MetricUnitScale.STANDARD_GRAVITY = 9.80665

-- Force, in newtons
MetricUnitScale.NEWTON = 1
MetricUnitScale.KILONEWTON = 1e3
MetricUnitScale.MEGANEWTON = 1e6
MetricUnitScale.POUND_FORCE = 0.45359237 * 9.80665

-- Energy, in joules
MetricUnitScale.JOULE = 1
MetricUnitScale.KILOJOULE = 1e3
MetricUnitScale.MEGAJOULE = 1e6
MetricUnitScale.KILOWATT_HOUR = 3.6e6
MetricUnitScale.KILOCALORIE = 4_184

-- Power, in watts
MetricUnitScale.WATT = 1
MetricUnitScale.KILOWATT = 1e3
MetricUnitScale.MEGAWATT = 1e6

-- Pressure, in pascals
MetricUnitScale.PASCAL = 1
MetricUnitScale.KILOPASCAL = 1e3
MetricUnitScale.MEGAPASCAL = 1e6
MetricUnitScale.BAR = 1e5
MetricUnitScale.POUND_FORCE_PER_SQUARE_INCH = 0.45359237 * 9.80665 / (0.0254 * 0.0254)

-- Density, in kilograms per cubic metre
MetricUnitScale.KILOGRAM_PER_CUBIC_METER = 1
MetricUnitScale.GRAM_PER_CUBIC_CENTIMETER = 1_000

-- Temperature, in kelvin
MetricUnitScale.KELVIN = 1
MetricUnitScale.CELSIUS = 1
MetricUnitScale.FAHRENHEIT = 5 / 9
MetricUnitScale.CELSIUS_ZERO = 273.15
MetricUnitScale.FAHRENHEIT_ZERO = 459.67 * 5 / 9

return table.freeze(MetricUnitScale)
