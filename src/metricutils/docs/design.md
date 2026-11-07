# MetricUnit design

Why `MetricUnit` is shaped the way it is. Written for whoever changes this package next; consumers
need only the API docs.

## One amount, one exponent vector

A value is an amount in SI base units plus a table of integer exponents by dimension name
(`{ length = 1, time = -1 }` for a speed). Every named unit is just a scale on that amount, so `*`
and `/` add and subtract exponents and need no table of conversions. A derived unit such as the
newton is not a separate kind: `MetricUnit.kilograms(1) * MetricUnit.metersPerSecondSquared(1)` and
`MetricUnit.newtons(1)` are the same value, and compare equal.

Any string is a dimension. Callers can measure `{ people = 1, length = -2 }` without this package
knowing about people, and it formats and errors sensibly using the name.

## SI base units

Amounts are held in seconds, metres, kilograms, bytes and kelvin. The module was first written for
a game whose clocks ran in days and whose maps were measured in kilometres, and held those as its
bases. That works for single dimensions, but derived units then carry factors such as
`86_400^2 / 1_000` and format as `kg·km/day^2`. With SI bases a newton, joule, watt and pascal are
each exactly 1, so the derived ladders in `MetricUnitCatalog` need no special cases.

The base is visible in two places: the number `MetricUnit.expect` and `GetBaseAmount` return, and
the `amount` in `toData`. Changing the base again would silently rescale every saved value, so treat
it as fixed.

## One name per unit

Every unit has one id, used everywhere: `"kilometer"` makes it (`MetricUnit.new(5, "kilometer")`),
reads it (`x:In("kilometer")`) and formats it (`{ unit = "kilometer" }`). Ids are singular, like the
unit identifiers of JavaScript's `Intl.NumberFormat`, but camelCase (`kilometerPerHour` where Intl
writes `kilometer-per-hour`) so they read as Luau names. Each has exactly one named constructor,
the id made plural (`MetricUnit.kilometers`, `MetricUnit.feet`, `MetricUnit.squareFeet`). The rates
and the temperature scales keep the id's name (`MetricUnit.perHour`, `MetricUnit.celsius`), because
their plurals read wrongly. Abbreviations such as `km` were removed: with one vocabulary there is
nothing to remember about which spelling a function uses.

Reading goes through one method, `In`, instead of a method per unit. A per-unit method set grows
with every unit added, and `perSecond` (make) beside `PerSecond` (read) was easy to confuse. The id
union is a type, so a typo fails in luau-lsp. `InSeconds` stays as the one named reader because it
is the hand-off to `task.wait` and `@quenty/time`, and reads as that intent at the call site.

There are 84 units. Adding one touches three places: its definition and ladder in
`MetricUnitCatalog`, its English names in `MetricUnitLocalizationUtils`, and its constructor on
`MetricUnit`. The localization spec walks every named dimension's units and fails if one has no
names.

## Absolute and difference

Temperature in °C or °F has an offset zero. 10 °C plus 10 °C is not 20 °C, but a 10 °C rise
added to 10 °C is. One flag, `absolute`, captures this, and the rules follow from treating an
absolute as a point and a difference as a vector:

| Operation | Result |
|---|---|
| absolute − absolute | difference |
| absolute ± difference, difference + absolute | absolute |
| absolute + absolute | error |
| difference − absolute | error |
| `*`, `/`, negate, `abs`, `pow`, `sqrt` on an absolute | error |
| comparing an absolute with a difference | error |

Kelvin is refused too, even though its zero is not offset. Allowing `kelvin(300) * 2` but not
`celsius(27) * 2` would make the same physical value behave differently depending on which
constructor made it.

The flag is separate from the dimensions, not a dimension of its own, so that an absolute and a
difference of the same quantity compare as the same dimension in error messages ("cannot compare an
absolute temperature and a temperature difference") and both read back through `In("celsius")`,
the absolute one from the scale's zero.

## Instants and spans

Time uses the same flag. A span (`MetricUnit.hours(2)`) is a difference; an instant
(`MetricUnit.instant(seconds)`) is a point in time, and follows every rule in the table above:
two instants subtract to a span, an instant plus a span is an instant, and adding two instants or
scaling one errors. This catches the bug where a timestamp is added to a timestamp, or doubled.

An instant does not know its epoch. `MetricUnit.instant(seconds)` counts from whatever the caller
measures from, such as a simulation's start; openfront keeps the world's clock on its own epoch,
centuries long. `MetricUnit.fromDateTime` and `x:ToDateTime()` use the Unix epoch. Mixing instants
from two epochs is the caller's bug, and nothing can check it, because the flag carries no epoch.
Recording one would make every instant carry an id and every operation compare it, for a mistake
that is rare.

The kind names follow from that. `"time"` stays a span, as it was before instants existed, so every
`expect(x, "time", ...)` still means a duration; `"instant"` is the point. (Temperature names its
absolute kind `"temperature"` and the other `"temperatureDifference"`; time keeps its existing name
for the far more common case.)

An instant reads as time since its epoch (`now:In("year")`), the way a temperature scale reads from
its zero. `tostring` writes `epoch + 1.5 min` so it cannot be mistaken for a span, and
`MetricUnit.format` writes the time since the epoch as a duration, since only the caller knows what
the epoch is; for a calendar date, use `Time.format(x:ToDateTime(), ...)`.

`between` and `addTo`, which used to cross to `DateTime`, are gone: `fromDateTime(b) -
fromDateTime(a)` and `(fromDateTime(dt) + span):ToDateTime()` say the same thing with the general
rules.

## A plain 0 has every dimension

`x + 0`, `MetricUnit.max(0, x)` and `MetricUnit.expect(0, "length", ...)` all work for any `x`.
Defaults and accumulators start at `0`, and zero is zero in every unit, so requiring
`MetricUnit.meters(0)` would add noise without catching anything. Any other plain number is
dimensionless, so `MetricUnit.kilometers(1) + 2` still errors. An absolute is the exception,
because 0 °C is not absolute zero and the epoch is not every instant.

## Two kinds of time

There are two different things people mean by "a year", and this package keeps them apart.

**Elapsed time** is the MetricUnit `time` dimension: exact seconds, the kind physics, cooldowns and
simulations run on. `MetricUnit.years` and `MetricUnit.months` are *averages* over that, for
long-range math. A year is a Julian year of 365.25 days, so a century of simulated history drifts
by leap days the way real ones do. A month is exactly a twelfth of that year, so
`months(12) == years(1)` and `years(1) / 12 == months(1)` hold exactly. No real month is
30.4375 days long; that is the point of an average.

**Calendar time** is `@quenty/time`. `Time.add(dateTime, 1, "month")` moves to the same day of the
next calendar month, January 31st becoming February 28th or 29th, and that span depends on where
it starts. `TimeDurationUtils` counts durations with a 365-day year and a 30-day month, which suits
"how long ago" text but not exact math.

Use elapsed time for anything you add, scale or compare: rates, lifetimes, simulated eras. Use
calendar time to land on a date a person would name. The crossings are explicit:

- `x:InSeconds()` hands exact seconds to `task.wait`, `os.time` arithmetic and
  `TimeDurationUtils`.
- `MetricUnit.fromDateTime(b) - MetricUnit.fromDateTime(a)` measures a calendar span as exact
  elapsed seconds. 2024 is 366 days, so it comes out longer than `years(1)`.
- `(MetricUnit.fromDateTime(dt) + x):ToDateTime()` moves a `DateTime` by exact seconds. To move by
  calendar months, use `Time.add`.

Time ids also accept `@quenty/time`'s `Time.TimeUnit` names (`"hours"`, `"h"`, `"Q"`), so the two
packages read the same words. The aliases are resolved in `MetricUnitCatalog` rather than through
`Time._normalizeUnit`, which is private, or `TimeDurationUtils.as`, which uses the 365/30 constants.
One consequence: in `@quenty/time`, `"m"` means minute, so `x:In("m")` reads minutes, not metres,
and errors on a length.

`MetricUnitScale` is the only place `YEAR` and `MONTH` are defined, and the specs read them from
there, so changing the average is a one-line edit. It would rescale every saved `years`/`months`
value, though.

## Studs and US customary units

A stud is 1/3.57 m, the constant `MetricUtils` has always used; both now read
`MetricUnitScale.STUDS_PER_METER`, so they cannot drift. US customary and imperial units use their
exact definitions (an inch is 0.0254 m, a pound 0.45359237 kg, a pound-force that pound under
standard gravity). Gallons are named `usGallon` and `imperialGallon`, because "gallon" alone means
different volumes in the US and the UK.

Neither studs nor customary units are ever picked by the formatter on its own. `system = "imperial"`
switches the ladders for the dimensions that have customary ones (miles/feet/inches, acres/square
feet, US gallons/fluid ounces, pounds/ounces, mph, pounds-force, psi, °F) and leaves the rest
metric. The default stays metric even for `en-us`: Roblox reports `en-us` for many players outside
the US, and a game usually wants one unit system for everyone, so the choice belongs to the game.

## Formatting

There are two writers. They share one unit catalog (`MetricUnitCatalog`: ids, scales, symbols and
the ladders that pick a unit by size). The catalog's tables are private; it exposes only lookups.

**`tostring`** is a debug string: English, symbols, four significant figures, the same in every
locale ("1.5 kN", "3.5 d", "1.6 MB/s", "epoch + 3 d"). Logs and test failures need a stable string,
and a debug string that changes with the player's locale is harder to search for.

**`MetricUnit.format` / `MetricUnitFormatUtils`** write text for players, modelled on JavaScript's
`Intl.NumberFormat` with `style: "unit"`: `locale`, `unitDisplay` short or long, the
fraction/significant digit options, `useGrouping`, a fixed `unit` or `perUnit`, `autoUnit = false` to
always write the SI base unit, and `system`. Override tables (`strings`, `perStrings`,
`durationStrings`) follow `@quenty/time`'s pattern of `{ one, other }` or a function, for languages
with more plural forms. `MetricUnitFormatUtils.format` takes a `MetricUnit` or its plain
`MetricUnitData`; it recognises a `MetricUnit` by its `ClassName` and reads it through its methods,
because requiring `MetricUnit` would be circular.

- **Numbers** go through `NumberLocalizationUtils`. Its `localize` groups digits for the locale but
  always writes "." as the decimal mark. Only `abbreviate` writes the locale's mark, so the
  formatter reads the mark off `abbreviate(0.5, locale)` once per locale and joins the parts itself.
- **Short display** writes unit symbols, which the SI defines as the same in every language. That
  means short display works for every locale `NumberLocalizationUtils` knows, using that locale's
  numbers, and needs no translated strings. The per-time phrases come from the locale's per table:
  `/s`, `/min`, `/h` and `/d` are SI symbols, while `/wk`, `/mo` and `/yr` are English and a
  language can replace them there.
- **Long display** writes names, which need translating. Only English ships, in American (`en`,
  `en-us`) and Commonwealth (`en-gb`, `en-au`, `en-ca`, `en-ie`, `en-nz`) spelling: meter/metre,
  liter/litre, metric ton/tonne. Another locale warns once and falls back to American English.
  Another language needs every name and its plural rule written by someone who knows the
  language, so none were guessed at.
- **Rates** pick the shortest time unit the value fills at least once, then write the numerator on
  its own ladder ("1.6 MB/s", "5 meters per second"). Frequency shares `1/time` with rates, so it
  reads "60/s" unless `unit = "hertz"` is given.
- **Temperatures** keep the absolute/difference split. An absolute temperature defaults to °C (°F
  under `imperial`) and is offset by the scale's zero. A difference defaults to K and is only
  scaled, so a 5 °C rise in °F is 9 °F, not 41 °F.

### Durations

A duration is broken into years, months, days, hours, minutes and seconds with *this package's*
averaged year and month, then each part is written with `@quenty/time`'s localized duration words
(`TimeLocalizationUtils`). That gives durations the 17 languages `@quenty/time` already covers
without this package translating any time words.

`TimeDurationUtils.format` and `humanize` are not called. Both renormalize through their own 365-
and 30-day constants: `toSeconds` sums a duration table with them, and `humanize` measures from a
`DateTime`. Through them `years(1)` (and `months(12)`, the same value) would read as a year and
6 hours, and `months(1)` as a month and 10.5 hours. The breakdown keeps the `maxParts` largest
non-zero units (two by default), like `TimeDurationUtils`' `largest`, and rounds only the smallest
one kept. Rounding up can fill a larger unit, so the rounded total is broken down a second time,
which turns "1 day, 24 hours" into "2 days". Durations under a millisecond, which `@quenty/time`
has no word for, are written in microseconds with this package's names ("40 microseconds"), or
the `µs` symbol in a locale without names. For clock-style text such as `36:00`, pass
`x:InSeconds()` to `TimeDurationUtils.format` with a template that has no year or month tokens.

The dependency runs one way: `metricutils` depends on `@quenty/time` and
`@quenty/clienttranslator`, and neither depends on `metricutils`.

### Known gaps

- `NumberLocalizationUtils.localize` keeps "." as the decimal mark (worked around above).
- `@quenty/time`'s Russian and Polish plural functions assume whole numbers, so a fractional
  duration such as 1.5 hours takes the wrong plural form there.
- There is no "in 2 days" / "an hour ago" text for MetricUnit durations. `TimeDurationUtils.humanize`
  gives it from `x:InSeconds()`, with its 365/30 counting.

## Left out on purpose

- **Angles.** Radians are dimensionless in SI. Giving angle its own dimension would make
  `radius * angle` a length·angle instead of an arc length and break every trig call. Treating
  degrees as a scale on dimensionless values would let any ratio read as an angle. Roblox already
  works in radians with `math.rad` and `math.deg`.
- **Electric units, moles and candela.** The exponent system would carry them cleanly (`current`,
  `amount`, `luminosity`), but few games need them. They can be added to the unit list the same way.
- **Sub-millimetre lengths, micrograms and terabytes.** No plausible game scale.
- **BTU, short tons and long tons.** BTU has several competing definitions and games rarely meet
  it; kilocalories and kilowatt-hours cover game energy. "Ton" means different masses in the US and
  the UK, and the metric tonne covers vehicles and cargo.
- **The `is*` predicates.** `isTime`, `isSpeed` and the rest were one function per kind. `isKind` and
  `IsKind` take the kind name, which is already a typed union.
