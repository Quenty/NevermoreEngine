## MetricUtils
<div align="center">
  <a href="http://quenty.github.io/NevermoreEngine/">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/docs.yml/badge.svg" alt="Documentation status" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/discord/385151591524597761?color=5865F2&label=discord&logo=discord&logoColor=white" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/build.yml/badge.svg" alt="Build and release status" />
  </a>
</div>

Typed, immutable measurements in metric, US customary and Roblox units, with localized formatting

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/MetricUnit">View docs →</a></div>

## Installation
```
npm install @quenty/metricutils --save
```

## Working on this package

[`docs/design.md`](docs/design.md) records why `MetricUnit` is shaped the way it is: SI base units,
the absolute/difference rule (temperatures and instants), the plain-`0` rule, elapsed versus calendar time, how formatting
hands durations to `@quenty/time`, and which units were left out on purpose.

## Usage

### MetricUnit

A `MetricUnit` is a frozen value that knows what it measures. Arithmetic checks dimensions, so adding a
length to a time errors instead of producing a silently wrong number.

Every unit has one id, such as `"kilometer"`, and one constructor, such as `MetricUnit.kilometers`. Read a
value in any unit of its dimension with `:In`.

```lua
local MetricUnit = require("MetricUnit")

local speed = MetricUnit.kilometers(36) / MetricUnit.hours(1)
print(speed:In("meterPerSecond")) --> 10
print(speed:In("milePerHour")) --> 22.369...
print(speed:GetKind()) --> speed
print(speed) --> 10 m/s

-- Derived units fall out of the arithmetic
local force = MetricUnit.kilograms(80) * MetricUnit.metersPerSecondSquared(9.81)
print(force:In("newton")) --> 784.8
local energy = MetricUnit.kilowatts(2) * MetricUnit.hours(3)
print(energy:In("kilowattHour")) --> 6

-- Units chosen at runtime, such as from a config
local reach = MetricUnit.new(30, "stud")

-- Mixing dimensions errors
local _ = MetricUnit.kilometers(1) + MetricUnit.seconds(1) --> error: cannot add length and time
```

Unit ids are a typed string union, so a typo in `:In("kilometr")` fails in luau-lsp. Time units also accept
`@quenty/time`'s names, such as `"hours"` and `"h"`. Rates read per a time unit with the `per` ids:
`MetricUnit.perDay(48):In("perHour")` is 2.

Use `MetricUnit.expect` to check an argument at an API boundary, and `isKind` to test one. `expect` returns
the amount in SI base units:

```lua
local function setReach(reach: MetricUnit.MetricUnit)
	local meters = MetricUnit.expect(reach, "length", "reach")
end

MetricUnit.isKind(value, "speed")
```

`GetKind`, `IsKind`, `IsAbsolute`, `GetDimensions`, `GetBaseAmount` and `GetUnitIds` describe a value; the
last lists every unit id it can be read in, for a settings menu to offer.

### Roblox studs and US customary units

Studs count 3.57 to the metre, the same constant `MetricUtils` uses. Inches, feet, yards, miles, acres, square
feet, US and imperial gallons, US fluid ounces, ounces, pounds, stone, miles per hour, knots, pounds-force and psi
use their exact definitions.

```lua
MetricUnit.studs(357):In("meter") --> 100
MetricUnit.pounds(1):In("kilogram") --> 0.45359237
```

### Temperatures and instants

Temperatures and points in time are either absolute (a point on a scale) or a difference between two. Two
absolutes subtract to a difference, and a difference added to an absolute gives an absolute:

```lua
local swing = MetricUnit.celsiusDifference(12)
print((MetricUnit.celsius(15) + swing):In("celsius")) --> 27
print((MetricUnit.celsius(15) - MetricUnit.celsius(10)):In("kelvin")) --> 5
local _ = MetricUnit.celsius(15) * 2 --> error: cannot multiply an absolute temperature

local worldStart = MetricUnit.instant(0) -- seconds since an epoch you choose
local now = worldStart + MetricUnit.years(250)
print((now - worldStart):In("year")) --> 250
```

`MetricUnit.toData` and `MetricUnit.fromData` convert to and from plain tables for saving.

### Formatting for players

`MetricUnit.format` writes localized text in the style of JavaScript's `Intl.NumberFormat` with
`style: "unit"`. `tostring` stays a fixed English debug string.

```lua
MetricUnit.format(MetricUnit.meters(2500)) --> 2.5 km
MetricUnit.format(MetricUnit.meters(2500), { unitDisplay = "long", locale = "en-gb" }) --> 2.5 kilometres
MetricUnit.format(MetricUnit.meters(1234.5), { unit = "meter", locale = "de-de" }) --> 1 234,5 m
MetricUnit.format(MetricUnit.kilobytesPerSecond(1600)) --> 1.6 MB/s
MetricUnit.format(MetricUnit.kilometersPerHour(90), { unit = "kilometerPerHour" }) --> 90 km/h
MetricUnit.format(MetricUnit.studs(357), { unit = "stud" }) --> 357 studs
MetricUnit.format(MetricUnit.newtons(1234), { maximumSignificantDigits = 2 }) --> 1.2 kN
```

Studs and US customary units are never picked unless asked for, with `unit` or with `system = "imperial"`,
which picks miles, feet, inches, pounds, mph, psi and °F where a dimension has them:

```lua
MetricUnit.format(MetricUnit.kilometers(5), { system = "imperial" }) --> 3.107 mi
MetricUnit.format(MetricUnit.celsius(100), { system = "imperial" }) --> 212 °F
```

Durations use `@quenty/time`'s duration words, so they are localized in every language it covers:

```lua
MetricUnit.format(MetricUnit.years(1)) --> 1 year
MetricUnit.format(MetricUnit.minutes(90)) --> 1 hour, 30 minutes
MetricUnit.format(MetricUnit.minutes(90), { locale = "es-es" }) --> 1 hora, 30 minutos
MetricUnit.format(MetricUnit.minutes(90), { unit = "hour" }) --> 1.5 hours
```

Short display uses unit symbols, so it works in any locale `NumberLocalizationUtils` supports. Long
names ship in English only, in American and Commonwealth spelling.

### Time

MetricUnit time is elapsed time in exact seconds. `MetricUnit.years` and `MetricUnit.months` are
averages for long-range math (a Julian year of 365.25 days, and a twelfth of it), not calendar
spans. To land on a date a person would name, such as "same day next month", use `Time.add` from
`@quenty/time`.

```lua
task.wait(MetricUnit.minutes(2):InSeconds()) -- exact seconds for task.wait, os.time and TimeDurationUtils

local played = MetricUnit.fromDateTime(DateTime.now()) - MetricUnit.fromDateTime(joinedAt) -- exact time between
local expires = (MetricUnit.fromDateTime(DateTime.now()) + MetricUnit.days(7)):ToDateTime() -- a DateTime a week on
```

### MetricUtils

`MetricUtils` converts between Roblox studs and metric, assuming 3.57 studs to the metre.

```lua
local MetricUtils = require("MetricUtils")

print(MetricUtils.studsToMeters(357)) --> 100
print(MetricUtils.studsPerSecondToKph(part.AssemblyLinearVelocity.Magnitude))
print(MetricUtils.getSoundDelaySeconds(1000)) -- seconds for sound to travel 1000 studs
```
