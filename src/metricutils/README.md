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

## Usage

A `MetricUnit` knows what it measures. Arithmetic checks dimensions, and any unit reads back with `:In`.

```lua
local MetricUnit = require("MetricUnit")

local speed = MetricUnit.kilometers(36) / MetricUnit.hours(1)
speed:In("meterPerSecond") --> 10
speed:In("milePerHour") --> 22.369
speed:GetKind() --> "speed"

local energy = MetricUnit.new(2, "kilowatt") * MetricUnit.hours(3)
energy:In("kilowattHour") --> 6

MetricUnit.kilometers(1) + MetricUnit.seconds(1) --> error: cannot add length and time
```

Roblox values come in through studs, and angles are their own dimension:

```lua
MetricUnit.fromStudVelocity(part.AssemblyLinearVelocity):In("kilometerPerHour")
MetricUnit.studs(100):In("meter") --> 28, at Roblox's 28 cm stud
CFrame.Angles(0, MetricUnit.degrees(90):In("radian"), 0)
```

Temperatures and points in time are absolute or a difference, so the arithmetic stays honest:

```lua
(MetricUnit.celsius(15) + MetricUnit.difference(12, "celsius")):In("celsius") --> 27
MetricUnit.celsius(15) * 2 --> error: cannot multiply an absolute temperature

local worldStart = MetricUnit.instant(0)
local now = worldStart + MetricUnit.years(250)
(now - worldStart):In("year") --> 250
```

Format for players in their language. A value shows itself in the system of the unit it was made from; convert it to show another. A locale never chooses the system:

```lua
MetricUnit.format(MetricUnit.meters(2500)) --> 2.5 km
MetricUnit.format(MetricUnit.meters(1234.5), { unit = "meter", locale = "de-de" }) --> 1 234,5 m
MetricUnit.format(MetricUnit.kilometers(5):ToUSCustomary()) --> 3.107 mi
MetricUnit.format(MetricUnit.new(2, "liter"):ToImperial()) --> 3.52 imp pt
MetricUnit.format(MetricUnit.minutes(90), { locale = "es-es" }) --> 1 hora, 30 minutos
MetricUnit.format(MetricUnit.minutes(90), { durationStyle = "clock" }) --> 1:30:00
```

`MetricUnitTranslator` streams unit names and symbols in 17 languages, one per player, from Unicode CLDR data:

```lua
local translator = serviceBag:GetService(require("MetricUnitTranslator"))
MetricUnit.format(MetricUnit.kilometers(5), { translator = translator }) --> 5 км in Russian, 5公里 in Chinese
```

The translations derive from Unicode CLDR; see the notice in `src/Shared/Localization/MetricUnitTranslator/init.lua`.

And read what players type:

```lua
MetricUnit.parse("1h30m") --> 90 minutes
MetricUnit.parse("5 m", "time") --> 5 minutes, since a time was expected
local value, err = MetricUnit.parse(textBox.Text, "length")
```

Units belong to systems: metric, US customary, British imperial and Roblox are built in, and a game can declare its own, such as studs at another scale:

```lua
local MINI = MetricUnitSystems.roblox({ name = "robloxMini", metersPerStud = 0.028 })
local height = MINI:New(5, "stud")
height:In("meter") --> 0.14
MetricUnit.format(height) --> 5 studs
MetricUnitSystems.IMPERIAL:Format(height) --> 5.512 in
MINI:Parse("5 studs", "length")
```

`MetricUtils` keeps its plain-number stud conversions at 3.57 studs to the metre, such as `MetricUtils.studsToMeters(357)`.
