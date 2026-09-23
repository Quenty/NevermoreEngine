--!strict
--[=[
	Durations. A duration is a length of time with no
	start point, kept as a number of seconds to match Roblox's `os.time`, `task.wait` and friends.
	A year is counted as 365 days and a month as 30 days when converting to and from
	seconds.

	```lua
	TimeDurationUtils.format({ hours = 1, minutes = 30 }, "hh:mm") --> 01:30
	TimeDurationUtils.humanize(TimeDurationUtils.toSeconds(2, "days")) --> 2 days
	TimeDurationUtils.toIsoString("PT90M") --> PT1H30M
	```

	@class TimeDurationUtils
]=]

local require = require(script.Parent.loader).load(script)

local RelativeTimeUtils = require("RelativeTimeUtils")
local Time = require("Time")
local TimeLocalizationUtils = require("TimeLocalizationUtils")

local TimeDurationUtils = {}

--[=[
	Units of a duration. Singular keys are accepted as well.

	@interface DurationTable
	.years number?
	.months number?
	.weeks number?
	.days number?
	.hours number?
	.minutes number?
	.seconds number?
	.milliseconds number?
	@within TimeDurationUtils
]=]
export type DurationTable = {
	years: number?,
	months: number?,
	weeks: number?,
	days: number?,
	hours: number?,
	minutes: number?,
	seconds: number?,
	milliseconds: number?,
}

--[=[
	A number of seconds, a [DurationTable], or an ISO 8601 duration such as `"P1DT12H"`.

	@type DurationLike number | DurationTable | string
	@within TimeDurationUtils
]=]
export type DurationLike = number | DurationTable | string

--[=[
	A duration broken into whole units, largest first, as [TimeDurationUtils.toTable] returns it.

	@interface DurationBreakdown
	.years number
	.months number
	.days number
	.hours number
	.minutes number
	.seconds number
	.milliseconds number
	@within TimeDurationUtils
]=]
export type DurationBreakdown = {
	years: number,
	months: number,
	days: number,
	hours: number,
	minutes: number,
	seconds: number,
	milliseconds: number,
}

--[=[
	See [TimeLocalizationUtils.DurationStringOverrides].

	@type DurationStringOverrides TimeLocalizationUtils.DurationStringOverrides
	@within TimeDurationUtils
]=]
export type DurationStringOverrides = TimeLocalizationUtils.DurationStringOverrides

--[=[
	Which zero-valued tokens [TimeDurationUtils.format] drops: `large` the leading ones, `small`
	the trailing ones, `mid` the interior ones, `both` leading and trailing, `all` every one and
	`false` none. The last remaining token is never dropped.

	@type DurationTrim "large" | "small" | "both" | "mid" | "all" | false
	@within TimeDurationUtils
]=]
export type DurationTrim = "large" | "small" | "both" | "mid" | "all" | false

--[=[
	Options for [TimeDurationUtils.format].

	@interface DurationFormatOptions
	.locale string? -- Picks the unit phrases through [TimeLocalizationUtils], defaults to English
	.strings DurationStringOverrides? -- Overrides the phrase for a unit, e.g. `{ hours = { one = "%d hr", other = "%d hrs" } }`
	.trim DurationTrim? -- Which zero tokens to drop, defaults to `large`
	.stopTrim string? -- Tokens never dropped, as a template such as `m`; `*` before a token in the template does the same
	.largest number? -- Show only this many of the largest non-zero tokens; implies `trim = "all"` unless `trim` is given
	.trunc boolean? -- Truncate the smallest token instead of rounding it
	.precision number? -- Decimal places on the smallest token; negative rounds to tens, hundreds and so on
	.forceLength boolean? -- Pad the first shown token to its template width even when a larger one was dropped
	.minValue number? -- Below this many of the smallest unit, print `< ` and the minimum instead
	.maxValue number? -- Above this many of the smallest unit, print `> ` and the maximum instead
	.limits { [string]: number }? -- How far a token may count before the next larger token is used: `{ minutes = 60 }` prints one hour as `60:00`, `{ hours = 47 }` prints a day and a half as `36:00:00`
	@within TimeDurationUtils
]=]
export type DurationFormatOptions = {
	locale: string?,
	strings: DurationStringOverrides?,
	trim: DurationTrim?,
	stopTrim: string?,
	largest: number?,
	trunc: boolean?,
	precision: number?,
	forceLength: boolean?,
	minValue: number?,
	maxValue: number?,
	limits: { [string]: number }?,
}

local SECONDS_A_MINUTE = 60
local SECONDS_AN_HOUR = 60 * SECONDS_A_MINUTE
local SECONDS_A_DAY = 24 * SECONDS_AN_HOUR
local SECONDS_A_WEEK = 7 * SECONDS_A_DAY
local SECONDS_A_MONTH = 30 * SECONDS_A_DAY
local SECONDS_A_YEAR = 365 * SECONDS_A_DAY

local UNIT_SECONDS: { [string]: number } = {
	millisecond = 0.001,
	second = 1,
	minute = SECONDS_A_MINUTE,
	hour = SECONDS_AN_HOUR,
	day = SECONDS_A_DAY,
	week = SECONDS_A_WEEK,
	month = SECONDS_A_MONTH,
	quarter = 3 * SECONDS_A_MONTH,
	year = SECONDS_A_YEAR,
}

-- Breakdown field for each unit that has one
local UNIT_BREAKDOWN_FIELD: { [string]: string } = {
	millisecond = "milliseconds",
	second = "seconds",
	minute = "minutes",
	hour = "hours",
	day = "days",
	week = "weeks",
	month = "months",
	year = "years",
}

-- ISO 8601 designators before and after the T
local ISO_DATE_UNITS: { [string]: number } = {
	Y = SECONDS_A_YEAR,
	M = SECONDS_A_MONTH,
	W = SECONDS_A_WEEK,
	D = SECONDS_A_DAY,
}
local ISO_TIME_UNITS: { [string]: number } = {
	H = SECONDS_AN_HOUR,
	M = SECONDS_A_MINUTE,
	S = 1,
}

type FormatToken = {
	letter: string,
	field: Time.TimeUnit?,
	milliseconds: number,
}

function TimeDurationUtils._formatToken(letter: string, field: Time.TimeUnit?, milliseconds: number): FormatToken
	return { letter = letter, field = field, milliseconds = milliseconds }
end

-- Template letters, largest first, with each unit's size in milliseconds
local FORMAT_TOKENS: { FormatToken } = {
	TimeDurationUtils._formatToken("y", "years", SECONDS_A_YEAR * 1000),
	TimeDurationUtils._formatToken("M", "months", SECONDS_A_MONTH * 1000),
	TimeDurationUtils._formatToken("w", "weeks", SECONDS_A_WEEK * 1000),
	TimeDurationUtils._formatToken("d", "days", SECONDS_A_DAY * 1000),
	TimeDurationUtils._formatToken("h", "hours", SECONDS_AN_HOUR * 1000),
	TimeDurationUtils._formatToken("m", "minutes", SECONDS_A_MINUTE * 1000),
	TimeDurationUtils._formatToken("s", "seconds", 1000),
	-- Centiseconds have no TimeUnit, so they take no limit and no `__` phrase
	TimeDurationUtils._formatToken("C", nil, 10),
	TimeDurationUtils._formatToken("S", "milliseconds", 1),
}

local FORMAT_TOKEN_RANK: { [string]: number } = {}
for rank, token in FORMAT_TOKENS do
	FORMAT_TOKEN_RANK[token.letter] = rank
end

-- One piece of a parsed template: literal text, or a unit token with its padding width
type FormatPart = {
	text: string?,
	rank: number?,
	width: number?,
	label: boolean?,
	stop: boolean?,
	hidden: boolean?,
	value: number?,
}

function TimeDurationUtils._unitSeconds(unit: Time.TimeUnit): number
	return UNIT_SECONDS[Time._normalizeUnit(unit)]
end

-- Truncates toward zero, so a negative duration breaks into negative parts
function TimeDurationUtils._truncate(value: number): number
	return if value < 0 then math.ceil(value) else math.floor(value)
end

function TimeDurationUtils._parseIsoPart(part: string, units: { [string]: number }, source: string): number
	local total = 0
	local index = 1

	while index <= #part do
		local numberText, letter, nextIndex = string.match(part, "^([-+]?[%d.,]*)(%a)()", index)
		assert(letter and units[letter], string.format("Bad ISO 8601 duration %q", source))

		local value = tonumber((string.gsub(numberText :: string, ",", "."))) or 0
		total += value * units[letter]
		index = nextIndex :: any
	end

	return total
end

function TimeDurationUtils._parseIso(iso: string): number
	local sign, body = string.match(iso, "^([-+]?)P(.*)$")
	assert(body, string.format("Bad ISO 8601 duration %q", iso))

	local datePart, timePart = string.match(body :: string, "^([^T]*)T(.*)$")
	if not datePart then
		datePart = body
		timePart = ""
	end

	local total = TimeDurationUtils._parseIsoPart(datePart :: string, ISO_DATE_UNITS, iso)
		+ TimeDurationUtils._parseIsoPart(timePart :: string, ISO_TIME_UNITS, iso)

	return if sign == "-" then -total else total
end

--[=[
	Normalizes any [DurationLike] to seconds. A bare number is seconds unless `unit` says
	otherwise, so `toSeconds(5, "minutes")` is `300`.
]=]
function TimeDurationUtils.toSeconds(duration: DurationLike, unit: Time.TimeUnit?): number
	if type(duration) == "number" then
		return if unit then duration * TimeDurationUtils._unitSeconds(unit) else duration
	elseif type(duration) == "string" then
		assert(unit == nil, "A unit cannot be given with an ISO 8601 duration")
		return TimeDurationUtils._parseIso(duration)
	elseif type(duration) == "table" then
		assert(unit == nil, "A unit cannot be given with a duration table")

		local total = 0
		for key, value in pairs(duration :: any) do
			assert(type(value) == "number", string.format("Bad value for %q", tostring(key)))
			total += value * TimeDurationUtils._unitSeconds(key)
		end

		return total
	else
		error(string.format("Bad duration %q", typeof(duration)))
	end
end

--[=[
	Normalizes any [DurationLike] to milliseconds. See [TimeDurationUtils.toSeconds].
]=]
function TimeDurationUtils.toMilliseconds(duration: DurationLike, unit: Time.TimeUnit?): number
	return TimeDurationUtils.toSeconds(duration, unit) * 1000
end

--[=[
	Returns the whole duration in one unit, fractional. `as(90, "minutes")`
	is `1.5`.
]=]
function TimeDurationUtils.as(duration: DurationLike, unit: Time.TimeUnit): number
	return TimeDurationUtils.toSeconds(duration) / TimeDurationUtils._unitSeconds(unit)
end

--[=[
	Breaks the duration into whole years, months, days, hours, minutes, seconds and milliseconds,
	largest first.
]=]
function TimeDurationUtils.toTable(duration: DurationLike): DurationBreakdown
	local seconds = TimeDurationUtils.toSeconds(duration)
	-- Work in whole milliseconds so fractional seconds do not leak float noise into the parts
	local remaining = TimeDurationUtils._truncate(seconds * 1000 + (if seconds < 0 then -0.5 else 0.5))

	local years = TimeDurationUtils._truncate(remaining / (SECONDS_A_YEAR * 1000))
	remaining = math.fmod(remaining, SECONDS_A_YEAR * 1000)
	local months = TimeDurationUtils._truncate(remaining / (SECONDS_A_MONTH * 1000))
	remaining = math.fmod(remaining, SECONDS_A_MONTH * 1000)
	local days = TimeDurationUtils._truncate(remaining / (SECONDS_A_DAY * 1000))
	remaining = math.fmod(remaining, SECONDS_A_DAY * 1000)
	local hours = TimeDurationUtils._truncate(remaining / (SECONDS_AN_HOUR * 1000))
	remaining = math.fmod(remaining, SECONDS_AN_HOUR * 1000)
	local minutes = TimeDurationUtils._truncate(remaining / (SECONDS_A_MINUTE * 1000))
	remaining = math.fmod(remaining, SECONDS_A_MINUTE * 1000)
	local wholeSeconds = TimeDurationUtils._truncate(remaining / 1000)
	remaining = math.fmod(remaining, 1000)

	return {
		years = years,
		months = months,
		days = days,
		hours = hours,
		minutes = minutes,
		seconds = wholeSeconds,
		milliseconds = remaining,
	}
end

--[=[
	Returns one whole unit of the breakdown: `get({ hours = 25 }, "hours")` is
	`1` and `get({ hours = 25 }, "days")` is `1`. Weeks are whole weeks within the days and
	quarters whole quarters within the months.
]=]
function TimeDurationUtils.get(duration: DurationLike, unit: Time.TimeUnit): number
	local normalized = Time._normalizeUnit(unit)
	local breakdown = TimeDurationUtils.toTable(duration)

	if normalized == "week" then
		return TimeDurationUtils._truncate(breakdown.days / 7)
	elseif normalized == "quarter" then
		return TimeDurationUtils._truncate(breakdown.months / 3)
	end

	return (breakdown :: any)[UNIT_BREAKDOWN_FIELD[normalized]]
end

--[=[
	Adds another duration, returning seconds. `unit` applies when `other` is a number.
]=]
function TimeDurationUtils.add(duration: DurationLike, other: DurationLike, unit: Time.TimeUnit?): number
	return TimeDurationUtils.toSeconds(duration) + TimeDurationUtils.toSeconds(other, unit)
end

--[=[
	Subtracts another duration, returning seconds. `unit` applies when `other` is a number.
]=]
function TimeDurationUtils.subtract(duration: DurationLike, other: DurationLike, unit: Time.TimeUnit?): number
	return TimeDurationUtils.toSeconds(duration) - TimeDurationUtils.toSeconds(other, unit)
end

--[=[
	Prints an amount with its unit, pluralized for the locale: `formatUnit("days", 1)` is
	`1 day` and `formatUnit("days", 45)` is `45 days`. The amount is printed as given, so
	`formatUnit("hours", 1.5)` is `1.5 hours`. Quarters have no phrase.

	```lua
	TimeDurationUtils.formatUnit("hours", 2, { locale = "es-es" }) --> 2 horas
	```
]=]
function TimeDurationUtils.formatUnit(unit: Time.TimeUnit, amount: number, options: DurationFormatOptions?): string
	assert(type(amount) == "number", "Bad amount")

	local field = UNIT_BREAKDOWN_FIELD[Time._normalizeUnit(unit)]
	assert(field, string.format("No duration phrase for %q", tostring(unit)))

	local overrides = if options then options.strings else nil
	local localeStrings: any =
		TimeLocalizationUtils.getDurationStringsForLocale(if options then options.locale else nil)
	local phrase = (if overrides then overrides[field] else nil) or localeStrings[field]
	assert(phrase, string.format("No duration phrase for %q", field))

	if type(phrase) == "function" then
		return phrase(amount)
	end

	local template = if math.abs(amount) == 1 then phrase.one else phrase.other
	return (string.gsub(template, "%%d", tostring(amount)))
end

function TimeDurationUtils._appendText(parts: { FormatPart }, text: string)
	local last = parts[#parts]
	if last and last.text then
		last.text ..= text
	else
		table.insert(parts, { text = text })
	end
end

function TimeDurationUtils._tokenizeTemplate(template: string): { FormatPart }
	local parts: { FormatPart } = {}
	local index = 1
	local stopNext = false

	while index <= #template do
		local char = string.sub(template, index, index)
		local rank = FORMAT_TOKEN_RANK[char]

		if char == "[" then
			local closeIndex = string.find(template, "]", index, true)
			if closeIndex then
				TimeDurationUtils._appendText(parts, string.sub(template, index + 1, closeIndex - 1))
				index = closeIndex + 1
			else
				TimeDurationUtils._appendText(parts, char)
				index += 1
			end
		elseif char == "*" then
			stopNext = true
			index += 1
		elseif rank then
			local width = 1
			while string.sub(template, index + width, index + width) == char do
				width += 1
			end
			index += width

			local labelEnd = string.match(template, "^%s*__()", index)
			table.insert(parts, { rank = rank, width = width, stop = stopNext, label = labelEnd ~= nil })
			stopNext = false
			if labelEnd then
				index = labelEnd :: any
			end
		else
			TimeDurationUtils._appendText(parts, char)
			index += 1
		end
	end

	return parts
end

-- Shown tokens, largest first
function TimeDurationUtils._getShownTokens(parts: { FormatPart }): { FormatPart }
	local shown: { FormatPart } = {}
	for _, part in parts do
		if part.rank and not part.hidden then
			table.insert(shown, part)
		end
	end

	table.sort(shown, function(a, b)
		return (a.rank :: number) < (b.rank :: number)
	end)

	return shown
end

-- The largest shown token absorbs everything above it, the smallest is rounded or truncated
-- to the precision, and the rest hold the remainder in between
function TimeDurationUtils._assignValues(
	parts: { FormatPart },
	totalMilliseconds: number,
	options: DurationFormatOptions
)
	local shown = TimeDurationUtils._getShownTokens(parts)
	local ranks: { number } = {}
	for _, part in shown do
		if ranks[#ranks] ~= part.rank then
			table.insert(ranks, part.rank :: number)
		end
	end

	local precision = options.precision or 0
	local unitsPerStep = 10 ^ precision
	local smallestMilliseconds = FORMAT_TOKENS[ranks[#ranks]].milliseconds

	local steps = totalMilliseconds / smallestMilliseconds * unitsPerStep
	steps = if options.trunc then math.floor(steps + 1e-9) else math.floor(steps + 0.5)

	local values: { [number]: number } = {}
	for i = 1, #ranks - 1 do
		local ratio = FORMAT_TOKENS[ranks[i]].milliseconds / smallestMilliseconds * unitsPerStep
		local value = math.floor(steps / ratio + 1e-9)
		steps -= value * ratio
		values[ranks[i]] = value
	end
	values[ranks[#ranks]] = steps / unitsPerStep

	for _, part in shown do
		part.value = values[part.rank :: number]
	end
end

function TimeDurationUtils._getStopRanks(options: DurationFormatOptions): { [number]: boolean }
	local stopRanks: { [number]: boolean } = {}
	if options.stopTrim then
		for _, part in TimeDurationUtils._tokenizeTemplate(options.stopTrim) do
			if part.rank then
				stopRanks[part.rank] = true
			end
		end
	end

	return stopRanks
end

function TimeDurationUtils._isPinned(part: FormatPart, stopRanks: { [number]: boolean }): boolean
	return part.stop == true or stopRanks[part.rank :: number] == true
end

function TimeDurationUtils._canHide(part: FormatPart, stopRanks: { [number]: boolean }): boolean
	return part.value == 0 and not TimeDurationUtils._isPinned(part, stopRanks)
end

-- Hides the largest shown token while the next smaller token can still count the whole
-- duration within its limit, so `{ minutes = 60 }` prints one hour as `60:00`
function TimeDurationUtils._applyLimits(
	parts: { FormatPart },
	totalMilliseconds: number,
	options: DurationFormatOptions
)
	local limits: { [string]: number } = {}
	for unit, limit in pairs(options.limits or {}) do
		limits[Time._normalizeUnit(unit :: any)] = limit
	end

	local stopRanks = TimeDurationUtils._getStopRanks(options)

	while true do
		local shown = TimeDurationUtils._getShownTokens(parts)
		local largest = shown[1]
		local largestRank = largest.rank :: number

		local next
		for _, part in shown do
			if part.rank ~= largestRank then
				next = part
				break
			end
		end
		if next == nil or TimeDurationUtils._isPinned(largest, stopRanks) then
			return
		end

		local nextField: Time.TimeUnit? = FORMAT_TOKENS[next.rank :: number].field
		local limit = if nextField then limits[Time._normalizeUnit(nextField)] else nil
		if limit == nil then
			return
		end

		for _, part in shown do
			if part.rank == largestRank then
				part.hidden = true
			end
		end
		TimeDurationUtils._assignValues(parts, totalMilliseconds, options)

		if (next.value :: number) > limit then
			for _, part in shown do
				if part.rank == largestRank then
					part.hidden = false
				end
			end
			TimeDurationUtils._assignValues(parts, totalMilliseconds, options)
			return
		end
	end
end

function TimeDurationUtils._trimParts(parts: { FormatPart }, options: DurationFormatOptions)
	local tokens: { FormatPart } = {}
	for _, part in parts do
		if part.rank then
			table.insert(tokens, part)
		end
	end

	local stopRanks = TimeDurationUtils._getStopRanks(options)

	local mode: any = options.trim
	if mode == nil then
		mode = if options.largest then "all" else "large" :: DurationTrim
	end

	if options.largest then
		local kept = 0
		for _, part in TimeDurationUtils._getShownTokens(parts) do
			if part.value ~= 0 and kept < options.largest then
				kept += 1
			elseif not TimeDurationUtils._isPinned(part, stopRanks) then
				part.hidden = true
			end
		end
	end

	if mode == "large" or mode == "both" or mode == "all" then
		for _, part in tokens do
			if part.hidden then
				continue
			elseif TimeDurationUtils._canHide(part, stopRanks) then
				part.hidden = true
			else
				break
			end
		end
	end

	if mode == "small" or mode == "both" or mode == "all" then
		for i = #tokens, 1, -1 do
			local part = tokens[i]
			if part.hidden then
				continue
			elseif TimeDurationUtils._canHide(part, stopRanks) then
				part.hidden = true
			else
				break
			end
		end
	end

	if mode == "mid" or mode == "all" then
		local firstShown, lastShown
		for i, part in tokens do
			if not part.hidden then
				firstShown = firstShown or i
				lastShown = i
			end
		end

		if firstShown and lastShown then
			for i = firstShown + 1, lastShown - 1 do
				if TimeDurationUtils._canHide(tokens[i], stopRanks) then
					tokens[i].hidden = true
				end
			end
		end
	end

	local anyShown = false
	for _, part in tokens do
		anyShown = anyShown or not part.hidden
	end
	if not anyShown and #tokens > 0 then
		tokens[#tokens].hidden = false
	end
end

function TimeDurationUtils._formatTokenValue(
	part: FormatPart,
	padded: boolean,
	isSmallest: boolean,
	options: DurationFormatOptions
): string
	local value = part.value :: number
	local precision = options.precision or 0
	local hasDecimals = isSmallest and precision > 0
	local text = if hasDecimals
		then string.format("%." .. precision .. "f", value)
		else tostring(math.floor(value + 0.5))

	if part.label then
		local field: Time.TimeUnit? = FORMAT_TOKENS[part.rank :: number].field
		assert(field, string.format("No duration phrase for %q", FORMAT_TOKENS[part.rank :: number].letter))
		return TimeDurationUtils.formatUnit(field, tonumber(text) :: number, options)
	end

	local width = part.width :: number
	local integerLength = #(string.match(text, "^%d+") :: string)
	if padded and integerLength < width then
		text = string.rep("0", width - integerLength) .. text
	end

	return text
end

-- A gap between tokens is dropped when the token before it was hidden, or when the token after
-- it starts a hidden run that reaches the end of the template
function TimeDurationUtils._isGapDropped(parts: { FormatPart }, index: number): boolean
	local previous, next
	for j = index - 1, 1, -1 do
		if parts[j].rank then
			previous = parts[j]
			break
		end
	end
	for j = index + 1, #parts do
		if parts[j].rank then
			next = parts[j]
			break
		end
	end

	if not previous or not next then
		return false
	elseif previous.hidden then
		return true
	elseif not next.hidden then
		return false
	end

	for j = index + 1, #parts do
		if parts[j].rank and not parts[j].hidden then
			return false
		end
	end

	return true
end

function TimeDurationUtils._renderParts(
	parts: { FormatPart },
	isNegative: boolean,
	options: DurationFormatOptions
): string
	local shown = TimeDurationUtils._getShownTokens(parts)
	local smallestRank = shown[#shown].rank

	local firstTokenIndex, firstShownIndex
	for i, part in parts do
		if part.rank then
			firstTokenIndex = firstTokenIndex or i
			if not part.hidden then
				firstShownIndex = firstShownIndex or i
			end
		end
	end

	local pieces: { string } = {}
	for i, part in parts do
		if part.text then
			if not TimeDurationUtils._isGapDropped(parts, i) then
				table.insert(pieces, part.text)
			end
		elseif not part.hidden then
			local padded = i == firstTokenIndex or i ~= firstShownIndex or options.forceLength == true
			if i == firstShownIndex and isNegative then
				table.insert(pieces, "-")
			end
			table.insert(pieces, TimeDurationUtils._formatTokenValue(part, padded, part.rank == smallestRank, options))
		end
	end

	return table.concat(pieces)
end

-- Picks a template from the duration's size, the way a person would write it
function TimeDurationUtils._defaultTemplate(totalMilliseconds: number): (string, DurationTrim)
	local breakdown: any = TimeDurationUtils.toTable(totalMilliseconds / 1000)
	local largest, smallest
	for _, field in { "years", "months", "days", "hours", "minutes", "seconds", "milliseconds" } do
		if breakdown[field] ~= 0 then
			largest = largest or field
			smallest = field
		end
	end

	if largest == nil then
		return "s __", "large" :: DurationTrim
	elseif largest == "milliseconds" then
		return "S __", "large" :: DurationTrim
	elseif largest == "seconds" or largest == "minutes" then
		return "*m:ss", "large" :: DurationTrim
	elseif largest == "hours" then
		return "h:mm:ss", "large" :: DurationTrim
	elseif largest == "days" then
		if smallest == "days" then
			return (if breakdown.days % 7 == 0 then "w __" else "d __"), "large" :: DurationTrim
		end
		return "w __, d __, h __", "both" :: DurationTrim
	elseif largest == smallest then
		return (if largest == "years" then "y __" else "M __"), "large" :: DurationTrim
	else
		return "y __, M __, d __", "both" :: DurationTrim
	end
end

--[=[
	Formats the duration with a template in the style of moment-duration-format. Tokens are `y`
	years, `M` months, `w` weeks, `d` days, `h` hours, `m` minutes, `s` seconds, `C`
	centiseconds and `S` milliseconds; repeating a letter zero pads it to that width. The largest token in the
	template absorbs everything above it, so `h:mm` on 47 hours is `47:00`, and the smallest
	token is rounded unless `trunc` is set. `__` after a token prints it as a localized phrase
	such as `2 days`, and text in square brackets is literal.

	Tokens whose value is zero are dropped from the front by default, so `h:mm:ss` on 45 seconds
	is `45`; see [DurationTrim]. Dropping a token also drops the text between it and its
	neighbour, so put unit words in `__` labels rather than brackets when trimming matters.
	Without a template, one is chosen from the duration's size: `250 milliseconds`, `2:03:00`,
	`3 days`, `1 week, 3 days, 2 hours` or `1 year, 2 months, 3 days`.

	```lua
	TimeDurationUtils.format(47 * 3600, "h:mm:ss") --> 47:00:00
	TimeDurationUtils.format(65.432, "mm:ss:CC", { trunc = true }) --> 01:05:43
	TimeDurationUtils.format({ days = 45 }, "d __") --> 45 days
	TimeDurationUtils.format(123 * 60, "d __ h:mm:ss") --> 2:03:00
	TimeDurationUtils.format({ days = 1, minutes = 5 }, "d __, h __, m __", { largest = 2 }) --> 1 day, 5 minutes
	TimeDurationUtils.format({ hours = 2 }, "h __", { locale = "es-es" }) --> 2 horas
	```
]=]
function TimeDurationUtils.format(duration: DurationLike, template: string?, options: DurationFormatOptions?): string
	local seconds = TimeDurationUtils.toSeconds(duration)
	local isNegative = seconds < 0
	local totalMilliseconds = math.floor(math.abs(seconds) * 1000 + 0.5)

	local resolved: DurationFormatOptions = if options then table.clone(options) else {}
	local str = template
	if str == nil then
		local defaultTemplate: string, defaultTrim: DurationTrim = TimeDurationUtils._defaultTemplate(totalMilliseconds)
		str = defaultTemplate
		if resolved.trim == nil then
			resolved.trim = defaultTrim
		end
	end

	local parts = TimeDurationUtils._tokenizeTemplate(str :: string)
	local shown = TimeDurationUtils._getShownTokens(parts)
	assert(#shown > 0, string.format("No unit tokens in duration template %q", str :: string))

	if resolved.minValue or resolved.maxValue then
		local smallestMilliseconds = FORMAT_TOKENS[shown[#shown].rank :: number].milliseconds
		local amount = totalMilliseconds / smallestMilliseconds
		local bounded: DurationFormatOptions = table.clone(resolved)
		bounded.minValue = nil
		bounded.maxValue = nil

		if resolved.minValue and amount < resolved.minValue then
			return "< " .. TimeDurationUtils.format(resolved.minValue * smallestMilliseconds / 1000, str, bounded)
		elseif resolved.maxValue and amount > resolved.maxValue then
			return "> " .. TimeDurationUtils.format(resolved.maxValue * smallestMilliseconds / 1000, str, bounded)
		end
	end

	TimeDurationUtils._assignValues(parts, totalMilliseconds, resolved)
	TimeDurationUtils._applyLimits(parts, totalMilliseconds, resolved)
	TimeDurationUtils._trimParts(parts, resolved)
	-- Rounding lands on the smallest token still shown
	TimeDurationUtils._assignValues(parts, totalMilliseconds, resolved)

	return TimeDurationUtils._renderParts(parts, isNegative, resolved)
end

--[=[
	Describes the duration in words through [RelativeTimeUtils]:
	`an hour`, `2 days`. With `withSuffix`, a positive duration reads `in an hour` and a negative
	one `an hour ago`. `options` can set the locale, thresholds or strings; its `withoutSuffix`
	is ignored in favour of `withSuffix`.
]=]
function TimeDurationUtils.humanize(
	duration: DurationLike,
	withSuffix: boolean?,
	options: RelativeTimeUtils.RelativeTimeOptions?
): string
	local now = DateTime.now()
	local later = DateTime.fromUnixTimestampMillis(now.UnixTimestampMillis + TimeDurationUtils.toMilliseconds(duration))

	local resolved: RelativeTimeUtils.RelativeTimeOptions = if options then table.clone(options) else {}
	resolved.withoutSuffix = not withSuffix

	return RelativeTimeUtils.from(later, now, resolved)
end

--[=[
	Formats the duration as an ISO 8601 string such as `P1DT12H` or `PT1.5S`. A zero duration is `P0D` and a negative one is prefixed with `-`.
]=]
function TimeDurationUtils.toIsoString(duration: DurationLike): string
	local breakdown = TimeDurationUtils.toTable(duration)
	local isNegative = TimeDurationUtils.toSeconds(duration) < 0

	local years = math.abs(breakdown.years)
	local months = math.abs(breakdown.months)
	local days = math.abs(breakdown.days)
	local hours = math.abs(breakdown.hours)
	local minutes = math.abs(breakdown.minutes)
	local seconds = math.abs(breakdown.seconds) + math.abs(breakdown.milliseconds) / 1000
	seconds = math.floor(seconds * 10000 + 0.5) / 10000

	local date = (if years ~= 0 then years .. "Y" else "")
		.. (if months ~= 0 then months .. "M" else "")
		.. (if days ~= 0 then days .. "D" else "")
	local time = (if hours ~= 0 then hours .. "H" else "")
		.. (if minutes ~= 0 then minutes .. "M" else "")
		.. (if seconds ~= 0 then seconds .. "S" else "")

	if date == "" and time == "" then
		return "P0D"
	end

	return (if isNegative then "-" else "") .. "P" .. date .. (if time ~= "" then "T" .. time else "")
end

return TimeDurationUtils
