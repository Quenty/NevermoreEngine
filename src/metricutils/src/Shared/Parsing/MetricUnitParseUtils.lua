--!strict
--[=[
	Reads measurements from text, for chat commands, admin tools, configs and text boxes. Returns plain
	[MetricUnitData]; [MetricUnit.parse] wraps it in a [MetricUnit].

	Accepts:

	- A number and a unit, with or without a space: `"5 km"`, `"5km"`, `"2.5 kilometers"`, `"45%"`, `"20 °C"`,
	  `"20C"`, `"-3 °F"`, `"60 mph"`, `"1.5 MiB"`. A unit is any unit id, constructor name, symbol, English name
	  (American or Commonwealth spelling), a common alias such as `"kph"` or `"Mbps"`, or one of `@quenty/time`'s
	  names for a time unit.
	- Several of one dimension, added up: `"1h30m"`, `"1 hour, 30 minutes"`, `"5 ft 3 in"`.
	- A composed unit: `"5 m/s"`, `"1.6 MB/s"`, `"6 m·kg/s"`, `"9.81 m/s^2"`, `"5/d"`.
	- Clock text: `"1:30"` is one minute thirty (`m:ss`) and `"1:30:00"` one hour thirty (`h:mm:ss`), as
	  [MetricUnitFormatUtils] writes them with `durationStyle = "clock"`.
	- An ISO 8601 duration without years or months, such as `"PT1H30M"`.

	Text such as `"m"` can name more than one unit: the metre, and `@quenty/time`'s minute. The rule is:

	1. With an expected `kind`, the unit of that kind wins: `parse("5 m", "time")` is five minutes.
	2. Otherwise, in text with several parts, the dimension every part can share wins: `"1m30s"` is minutes.
	3. Otherwise the SI symbol wins over `@quenty/time`'s alias: `"5 m"` is five metres.

	Symbols match case exactly (`"MB"` is a megabyte, `"Mb"` is not); names match without case (`"Kilometers"`).
	Numbers use the locale's decimal mark when `options.locale` is given (`"1,5 km"` in `de-de`), else `.`.
	No-break spaces read as spaces, so formatted text reads back.

	@class MetricUnitParseUtils
]=]

local require = require(script.Parent.loader).load(script)

local MetricUnitDefinitions = require("MetricUnitDefinitions")
local MetricUnitDimensionUtils = require("MetricUnitDimensionUtils")
local MetricUnitDisplayUnitUtils = require("MetricUnitDisplayUnitUtils")
local MetricUnitFallbackStrings = require("MetricUnitFallbackStrings")
local MetricUnitFormatUtils = require("MetricUnitFormatUtils")
local MetricUnitKinds = require("MetricUnitKinds")
local MetricUnitSystem = require("MetricUnitSystem")
local TimeDurationUtils = require("TimeDurationUtils")

local MetricUnitParseUtils = {}

--[=[
	Options for [MetricUnitParseUtils.parse].

	@interface ParseOptions
	.locale string? -- Reads numbers with this locale's decimal mark and grouping, defaults to `.` and `,`
	.defaultUnit UnitLike? -- The unit of a bare number, such as `"meter"` for a field of metres
	@within MetricUnitParseUtils
]=]
export type ParseOptions = {
	locale: string?,
	defaultUnit: MetricUnitDefinitions.UnitLike?,
	_system: MetricUnitSystem.MetricUnitSystem?,
}

type Dimensions = MetricUnitDimensionUtils.Dimensions
type UnitDefinition = MetricUnitDefinitions.UnitDefinition
type MetricUnitData = MetricUnitFormatUtils.MetricUnitData

type Expectation = { dimensions: Dimensions?, absolute: boolean? }
type MeasuredUnit = { factor: number, dimensions: Dimensions, zero: number? }
type Term = { number: number, unitText: string, units: { MeasuredUnit } }

local NO_BREAK_SPACES = { "\u{00A0}", "\u{202F}" }
local MINUS_SIGN = "\u{2212}"
local LOOKALIKE_SYMBOLS = table.freeze({
	{ "\u{03BC}", "\u{00B5}" }, -- Greek mu, as CLDR writes micro, to the micro sign
	{ "\u{2126}", "\u{03A9}" }, -- ohm sign to Greek omega
})
local CLOCK_WITH_HOURS = "^([-+]?)(%d+):(%d%d):(%d%d%.?%d*)$"
local CLOCK_WITHOUT_HOURS = "^([-+]?)(%d+):(%d%d%.?%d*)$"
local ISO_DURATION_START = "^[-+]?P[%dT]"
local ISO_DATE_PART = "^[-+]?P([^T]*)"
local COMPOSITION_MARKS = table.freeze({ "/", "·", "*", "^", "²", "³" })
local SUPERSCRIPT_POWERS: { [string]: number } = { ["²"] = 2, ["³"] = 3 }
local UNSPACED_SYMBOLS: { [string]: true } = { ["°"] = true, ["%"] = true }

local AliasPriority = table.freeze({
	ID_SYMBOL_OR_NAME = 1,
	UNIT_ALIAS = 2,
	SYMBOL_ANOTHER_UNIT_HAD_FIRST = 3,
	TIME_ALIAS = 4,
})

type UnitMatch = { unit: UnitDefinition, priority: number }

type UnitIndex = {
	exactText: { [string]: { UnitMatch } },
	lowercaseNames: { [string]: { UnitMatch } },
	fallback: UnitIndex?,
}

local function addMatch(matches: { [string]: { UnitMatch } }, text: string, unit: UnitDefinition, priority: number)
	local found = matches[text]
	if not found then
		found = {}
		matches[text] = found
	end
	for _, match in found do
		if match.unit.id == unit.id then
			match.priority = math.min(match.priority, priority)
			return
		end
	end
	table.insert(found, { unit = unit, priority = priority })
end

local function addSymbol(index: UnitIndex, symbol: string, unit: UnitDefinition, priority: number)
	addMatch(index.exactText, symbol, unit, priority)
end

local function addName(index: UnitIndex, name: string, unit: UnitDefinition, priority: number)
	addMatch(index.exactText, name, unit, priority)
	addMatch(index.lowercaseNames, string.lower(name), unit, priority)
end

local function buildIndex(units: { UnitDefinition }, fallback: UnitIndex?): UnitIndex
	local index: UnitIndex = { exactText = {}, lowercaseNames = {}, fallback = fallback }
	for _, unit in units do
		local isBareRate = unit.per ~= nil

		addName(index, unit.id, unit, AliasPriority.ID_SYMBOL_OR_NAME)
		if not isBareRate then
			local symbolPriority = if index.exactText[unit.symbol]
				then AliasPriority.SYMBOL_ANOTHER_UNIT_HAD_FIRST
				else AliasPriority.ID_SYMBOL_OR_NAME
			addSymbol(index, unit.symbol, unit, symbolPriority)
		end
		if unit.names then
			for _, name in { unit.names.one, unit.names.other } do
				addName(index, name, unit, AliasPriority.ID_SYMBOL_OR_NAME)
				addName(
					index,
					MetricUnitFallbackStrings.toCommonwealthSpelling(name),
					unit,
					AliasPriority.ID_SYMBOL_OR_NAME
				)
			end
		end
		local aliases: { string } = unit.aliases or {}
		for _, alias in aliases do
			addName(index, alias, unit, AliasPriority.UNIT_ALIAS)
		end
	end
	return index
end

type PrefixSpelling = { prefix: MetricUnitDefinitions.Prefix, text: string, isName: boolean }

local wellKnownUnits: UnitIndex? = nil
local prefixSpellingsLongestFirst: { PrefixSpelling }? = nil

local INDEX_BY_SYSTEM: { [MetricUnitSystem.MetricUnitSystem]: UnitIndex } = setmetatable({} :: any, { __mode = "k" })

local function trim(text: string): string
	return string.match(text, "^%s*(.-)%s*$") :: string
end

--[=[
	Reads `text` as a measurement. Returns the measurement as plain data, or nil and a message suitable to show a
	player. `kind` is what the caller expects, such as `"length"`; it settles ambiguous units and turns a mismatch or
	a bare number into a helpful message.

	```lua
	MetricUnitParseUtils.parse("5 km") -- { amount = 5000, dimensions = { length = 1 } }
	MetricUnitParseUtils.parse("5", "length") -- nil, 'Add a unit, such as "5 m"'
	MetricUnitParseUtils.parse("5", "length", { defaultUnit = "meter" }) -- { amount = 5, dimensions = { length = 1 } }
	MetricUnitParseUtils.parse("20 C") -- an absolute temperature
	MetricUnitParseUtils.parse("20 C", "temperatureDifference") -- a difference of 20 K
	```

	@param text string
	@param kind (KindName | Dimensions)?
	@param options ParseOptions?
	@return MetricUnitData?
	@return string?
]=]
function MetricUnitParseUtils.parse(
	text: string,
	kind: (MetricUnitKinds.KindName | Dimensions)?,
	options: ParseOptions?
): (MetricUnitData?, string?)
	if type(text) ~= "string" then
		return nil, "Enter a value"
	end

	local expected: Expectation = {}
	if kind ~= nil then
		local dimensions, absolute = MetricUnitKinds.fromName(kind)
		expected = { dimensions = dimensions, absolute = absolute }
	end

	local normalized = MetricUnitParseUtils._normalizeText(text)
	if normalized == "" then
		return nil, "Enter a value"
	end

	local data, err = MetricUnitParseUtils._readText(normalized, expected, options or {})
	if not data then
		return nil, err
	end
	return MetricUnitParseUtils._checkKind(data, expected, normalized)
end

function MetricUnitParseUtils._parseInSystem(
	text: string,
	kind: (MetricUnitKinds.KindName | Dimensions)?,
	options: ParseOptions?,
	system: MetricUnitSystem.MetricUnitSystem?
): (MetricUnitData?, string?)
	local resolved: ParseOptions = if options then table.clone(options) else {}
	resolved._system = system
	return MetricUnitParseUtils.parse(text, kind, resolved)
end

function MetricUnitParseUtils._normalizeText(text: string): string
	local normalized = text
	for _, space in NO_BREAK_SPACES do
		normalized = string.gsub(normalized, space, " ")
	end
	for _, pair in LOOKALIKE_SYMBOLS do
		normalized = string.gsub(normalized, pair[1], pair[2])
	end
	normalized = trim(normalized)
	return (string.gsub(normalized, MINUS_SIGN, "-"))
end

function MetricUnitParseUtils._readText(
	text: string,
	expected: Expectation,
	options: ParseOptions
): (MetricUnitData?, string?)
	local clockSeconds = MetricUnitParseUtils._readClockSeconds(text)
	if clockSeconds then
		return MetricUnitParseUtils._durationData(clockSeconds), nil
	elseif string.match(text, ISO_DURATION_START) then
		return MetricUnitParseUtils._readIsoDuration(text)
	else
		return MetricUnitParseUtils._readMeasurement(text, expected, options)
	end
end

function MetricUnitParseUtils._readClockSeconds(text: string): number?
	local sign, hours, minutes, seconds = string.match(text, CLOCK_WITH_HOURS)
	if not hours then
		sign, minutes, seconds = string.match(text, CLOCK_WITHOUT_HOURS)
	end
	if not minutes then
		return nil
	end

	local total = (tonumber(hours) or 0) * 3600 + (tonumber(minutes) :: number) * 60 + (tonumber(seconds) :: number)
	return if sign == "-" then -total else total
end

function MetricUnitParseUtils._readIsoDuration(text: string): (MetricUnitData?, string?)
	local datePart = string.match(text, ISO_DATE_PART) or ""
	if string.find(datePart, "[YM]") then
		return nil, 'ISO years and months are calendar spans; write them as "1 year" or "2 months"'
	end

	local ok, seconds = pcall(TimeDurationUtils.toSeconds, text)
	if not ok then
		return nil, string.format("Could not read the duration %q", text)
	end
	return MetricUnitParseUtils._durationData(seconds :: number), nil
end

function MetricUnitParseUtils._durationData(seconds: number): MetricUnitData
	return { amount = seconds, dimensions = { time = 1 } }
end

function MetricUnitParseUtils._readMeasurement(
	text: string,
	expected: Expectation,
	options: ParseOptions
): (MetricUnitData?, string?)
	local decimalMark = if options.locale then MetricUnitFormatUtils.getDecimalSeparator(options.locale) else "."
	local index = MetricUnitParseUtils._indexFor(options._system)
	local terms, err = MetricUnitParseUtils._splitTerms(text, decimalMark, index)
	if not terms then
		return nil, err
	end

	local isBareNumber = #terms == 1 and terms[1].unitText == ""
	if isBareNumber then
		return MetricUnitParseUtils._readBareNumber(terms[1].number, expected, options)
	end
	return MetricUnitParseUtils._combineTerms(terms, text, expected)
end

function MetricUnitParseUtils._splitTerms(text: string, decimalMark: string, index: UnitIndex): ({ Term }?, string?)
	local terms: { Term } = {}
	local position = 1

	while position <= #text do
		local number, afterNumber = MetricUnitParseUtils._readNumber(text, position, decimalMark)
		local startsWithBareRate = #terms == 0 and string.sub(text, position, position) == "/"
		if number == nil and startsWithBareRate then
			number = 1
		end
		if number == nil then
			return nil, string.format("Could not read %q", text)
		end

		local unitText, afterUnit = MetricUnitParseUtils._readUnitText(text, afterNumber, index)
		local units = MetricUnitParseUtils._unitsNamedBy(unitText, index)
		local isUnknownUnit = unitText ~= "" and #units == 0
		if isUnknownUnit then
			return nil, string.format("Unknown unit %q", unitText)
		end

		table.insert(terms, { number = number, unitText = unitText, units = units })
		position = MetricUnitParseUtils._skipTermSeparator(text, afterUnit)
	end

	return terms, nil
end

function MetricUnitParseUtils._readNumber(text: string, position: number, decimalMark: string): (number?, number)
	local sign = string.match(text, "^[-+]", position)
	local afterSign = if sign then position + 1 else position

	local groupMarks = MetricUnitParseUtils._groupMarkPatterns(decimalMark)
	local integerDigits, afterInteger = MetricUnitParseUtils._readGroupedDigits(text, afterSign, groupMarks)
	local fractionDigits, afterFraction = MetricUnitParseUtils._readFraction(text, afterInteger, decimalMark)
	if integerDigits == "" and fractionDigits == "" then
		return nil, position
	end

	local value = tonumber(
		(if integerDigits == "" then "0" else integerDigits)
			.. "."
			.. (if fractionDigits == "" then "0" else fractionDigits)
	)
	assert(value, "Bad number")
	return if sign == "-" then -value else value, afterFraction
end

function MetricUnitParseUtils._groupMarkPatterns(decimalMark: string): { string }
	return if decimalMark == "," then { "%.", " " } else { "," }
end

function MetricUnitParseUtils._readGroupedDigits(
	text: string,
	position: number,
	groupMarks: { string }
): (string, number)
	local digits = string.match(text, "^%d+", position)
	if not digits then
		return "", position
	end

	local index = position + #digits
	while true do
		local groupDigits, afterGroup = MetricUnitParseUtils._readDigitGroup(text, index, groupMarks)
		if not groupDigits then
			break
		end
		digits ..= groupDigits
		index = afterGroup
	end
	return digits, index
end

function MetricUnitParseUtils._readDigitGroup(text: string, position: number, groupMarks: { string }): (string?, number)
	for _, mark in groupMarks do
		local group, groupDigits = string.match(text, "^(" .. mark .. "(%d%d%d))", position)
		local afterGroup = position + #(group or "")
		local isExactlyThreeDigits = group ~= nil and not string.match(text, "^%d", afterGroup)
		if isExactlyThreeDigits then
			return groupDigits, afterGroup
		end
	end
	return nil, position
end

function MetricUnitParseUtils._readFraction(text: string, position: number, decimalMark: string): (string, number)
	local afterMark = position + #decimalMark
	if string.sub(text, position, afterMark - 1) ~= decimalMark then
		return "", position
	end

	local digits = string.match(text, "^%d+", afterMark)
	if not digits then
		return "", position
	end
	return digits, afterMark + #digits
end

function MetricUnitParseUtils._readUnitText(text: string, position: number, index: UnitIndex): (string, number)
	local unitStart = position + #(string.match(text, "^%s*", position) :: string)
	local unitText = string.sub(text, unitStart, MetricUnitParseUtils._findNextTermSeparator(text, unitStart) - 1)
	if #MetricUnitParseUtils._unitsNamedBy(unitText, index) == 0 then
		unitText = MetricUnitParseUtils._unitBeforeGluedNumber(unitText, index) or unitText
	end

	local afterUnit = unitStart + #unitText
	return (string.gsub(unitText, "[%s,]+$", "")), afterUnit
end

function MetricUnitParseUtils._findNextTermSeparator(text: string, position: number): number
	local endOfText = #text + 1
	local beforeNumber = string.find(text, "[%s,]+[-+]?%d", position) or endOfText
	local beforeAndNumber = string.find(text, "%s+and%s+[-+]?%d", position) or endOfText
	return math.min(beforeNumber, beforeAndNumber)
end

function MetricUnitParseUtils._unitBeforeGluedNumber(unitText: string, index: UnitIndex): string?
	local letters = string.match(unitText, "^([^%d%s]+)%d")
	if letters and #MetricUnitParseUtils._findUnitsBestFirst(letters, index) > 0 then
		return letters
	end
	return nil
end

function MetricUnitParseUtils._skipTermSeparator(text: string, position: number): number
	local separator = string.match(text, "^[%s,]*and%s+", position) or string.match(text, "^[%s,]*", position)
	return position + #(separator :: string)
end

function MetricUnitParseUtils._unitsNamedBy(unitText: string, index: UnitIndex): { MeasuredUnit }
	local units: { MeasuredUnit } = {}
	for _, unit in MetricUnitParseUtils._findUnitsBestFirst(unitText, index) do
		table.insert(units, unit)
	end
	if #units > 0 then
		return units
	end
	local composed = MetricUnitParseUtils._composeUnit(unitText, index)
	return if composed then { composed } else {}
end

function MetricUnitParseUtils._wellKnownIndex(): UnitIndex
	local found = wellKnownUnits
	if found then
		return found
	end
	local index = buildIndex(MetricUnitDefinitions.getDeclaredUnits(), nil)
	for timeAlias, id in MetricUnitDefinitions.getTimeAliases() do
		addSymbol(index, timeAlias, assert(MetricUnitDefinitions.getUnit(id), id), AliasPriority.TIME_ALIAS)
	end
	wellKnownUnits = index
	return index
end

function MetricUnitParseUtils._indexFor(system: MetricUnitSystem.MetricUnitSystem?): UnitIndex
	if not system then
		return MetricUnitParseUtils._wellKnownIndex()
	end
	local index = INDEX_BY_SYSTEM[system]
	if not index then
		index = buildIndex(system:GetUnits(), MetricUnitParseUtils._indexFor(system:GetFallback()))
		INDEX_BY_SYSTEM[system] = index
	end
	return index
end

function MetricUnitParseUtils._findUnitsBestFirst(text: string, index: UnitIndex): { UnitDefinition }
	local spelledExactly = MetricUnitParseUtils._findUnitsNamed(text, index, true)
	if #spelledExactly > 0 then
		return spelledExactly
	end
	local prefixed = MetricUnitParseUtils._findPrefixedUnits(text, index)
	if #prefixed > 0 then
		return prefixed
	end
	return MetricUnitParseUtils._findUnitsNamed(text, index, false)
end

function MetricUnitParseUtils._findPrefixedUnits(text: string, index: UnitIndex): { UnitDefinition }
	local lowercaseText = string.lower(text)
	for _, spelling in MetricUnitParseUtils._prefixSpellingsLongestFirst() do
		local start = if spelling.isName
			then string.sub(lowercaseText, 1, #spelling.text)
			else string.sub(text, 1, #spelling.text)
		local rest = string.sub(text, #spelling.text + 1)
		if start == spelling.text and rest ~= "" then
			for _, base in MetricUnitParseUtils._findUnitsNamed(rest, index, false) do
				local unit = MetricUnitDefinitions.getPrefixedUnit(spelling.prefix, base)
				local isSpelledAsSiWritesIt = not spelling.isName
					or (unit ~= nil and unit.id == spelling.text .. base.id)
				if unit and isSpelledAsSiWritesIt then
					return { unit }
				end
			end
		end
	end
	return {}
end

function MetricUnitParseUtils._prefixSpellingsLongestFirst(): { PrefixSpelling }
	local found = prefixSpellingsLongestFirst
	if found then
		return found
	end
	local spellings: { PrefixSpelling } = {}
	for _, prefix in MetricUnitDefinitions.getPrefixes() do
		table.insert(spellings, { prefix = prefix, text = prefix.symbol, isName = false })
		table.insert(spellings, { prefix = prefix, text = prefix.name, isName = true })
		local lastLetter = string.sub(prefix.name, -1)
		if lastLetter == "a" or lastLetter == "o" then
			table.insert(spellings, { prefix = prefix, text = string.sub(prefix.name, 1, -2), isName = true })
		end
		if prefix.name == "micro" then
			table.insert(spellings, { prefix = prefix, text = "u", isName = false })
		end
	end
	table.sort(spellings, function(a, b)
		return #a.text > #b.text
	end)
	prefixSpellingsLongestFirst = spellings
	return spellings
end

function MetricUnitParseUtils._findUnitsNamed(text: string, index: UnitIndex, matchCase: boolean): { UnitDefinition }
	local lowercaseText = string.lower(text)
	local matches: { UnitMatch }? = nil
	local searched: UnitIndex? = index
	while searched and not matches do
		matches = searched.exactText[text] or (if matchCase then nil else searched.lowercaseNames[lowercaseText])
		searched = searched.fallback
	end
	if not matches then
		return {}
	end

	local ranked = table.clone(matches)
	table.sort(ranked, function(a, b)
		return a.priority < b.priority
	end)

	local units: { UnitDefinition } = {}
	for _, match in ranked do
		table.insert(units, match.unit)
	end
	return units
end

function MetricUnitParseUtils._hasCompositionMark(unitText: string): boolean
	for _, mark in COMPOSITION_MARKS do
		if string.find(unitText, mark, 1, true) then
			return true
		end
	end
	return false
end

function MetricUnitParseUtils._splitFactors(text: string): { string }
	local factors: { string } = {}
	for _, factorText in string.split((string.gsub(text, "·", "*")), "*") do
		local trimmed = trim(factorText)
		if trimmed ~= "" then
			table.insert(factors, trimmed)
		end
	end
	return factors
end

function MetricUnitParseUtils._composeUnit(unitText: string, index: UnitIndex): MeasuredUnit?
	if not MetricUnitParseUtils._hasCompositionMark(unitText) then
		return nil
	end

	local factor = 1
	local dimensions: Dimensions = MetricUnitDimensionUtils.NONE
	for position, part in string.split(unitText, "/") do
		local isNumerator = position == 1
		local exponentSign = if isNumerator then 1 else -1
		local trimmedPart = trim(part)
		if trimmedPart == "" then
			if isNumerator then
				continue
			end
			return nil
		end

		for _, factorText in MetricUnitParseUtils._splitFactors(trimmedPart) do
			local unit, power = MetricUnitParseUtils._readUnitPower(factorText, index)
			if not unit then
				return nil
			end
			factor *= unit.factor ^ (exponentSign * power)
			dimensions = MetricUnitDimensionUtils.combine(
				dimensions,
				MetricUnitDimensionUtils.scale(unit.dimensions, power),
				exponentSign
			)
		end
	end
	return { factor = factor, dimensions = dimensions }
end

function MetricUnitParseUtils._readUnitPower(factorText: string, index: UnitIndex): (UnitDefinition?, number)
	local unitText, power = MetricUnitParseUtils._splitPower(factorText)
	local unit = MetricUnitParseUtils._findUnitsBestFirst(unitText, index)[1]
	if unit and unit.per == nil then
		return unit, power
	end
	return nil, power
end

function MetricUnitParseUtils._splitPower(factorText: string): (string, number)
	for superscript, power in SUPERSCRIPT_POWERS do
		if string.sub(factorText, -#superscript) == superscript then
			return string.sub(factorText, 1, -#superscript - 1), power
		end
	end
	local unitText, power = string.match(factorText, "^(.-)%^(%-?%d+)$")
	if unitText then
		return unitText, tonumber(power) :: number
	end
	return factorText, 1
end

function MetricUnitParseUtils._readBareNumber(
	number: number,
	expected: Expectation,
	options: ParseOptions
): (MetricUnitData?, string?)
	if options.defaultUnit then
		local system = options._system
		local unit = if system
			then system:GetUnit(options.defaultUnit)
			else MetricUnitDefinitions.getUnit(options.defaultUnit)
		assert(unit, string.format("Bad defaultUnit %q", tostring(options.defaultUnit)))
		return MetricUnitParseUtils._unitData(number, unit, expected.absolute), nil
	end

	local expectedDimensions = expected.dimensions
	if expectedDimensions and next(expectedDimensions) ~= nil then
		return nil, MetricUnitParseUtils._addUnitMessage(number, expectedDimensions)
	end
	return { amount = number, dimensions = {} }, nil
end

function MetricUnitParseUtils._combineTerms(
	terms: { Term },
	text: string,
	expected: Expectation
): (MetricUnitData?, string?)
	local dimensions = MetricUnitParseUtils._chooseDimensions(terms, expected.dimensions)
	if #terms == 1 then
		local unit, err = MetricUnitParseUtils._pickUnit(terms[1], dimensions, text)
		if not unit then
			return nil, err
		end
		return MetricUnitParseUtils._unitData(terms[1].number, unit, expected.absolute), nil
	end
	return MetricUnitParseUtils._sumTerms(terms, dimensions, text, expected)
end

function MetricUnitParseUtils._chooseDimensions(terms: { Term }, expectedDimensions: Dimensions?): Dimensions?
	return expectedDimensions
		or MetricUnitParseUtils._dimensionsEveryTermShares(terms)
		or MetricUnitParseUtils._bestDimensionsOf(terms[1])
end

function MetricUnitParseUtils._dimensionsEveryTermShares(terms: { Term }): Dimensions?
	for _, unit in terms[1].units do
		if MetricUnitParseUtils._everyTermCanBe(terms, unit.dimensions) then
			return unit.dimensions
		end
	end
	return nil
end

function MetricUnitParseUtils._everyTermCanBe(terms: { Term }, dimensions: Dimensions): boolean
	for _, term in terms do
		if not MetricUnitParseUtils._termCanBe(term, dimensions) then
			return false
		end
	end
	return true
end

function MetricUnitParseUtils._termCanBe(term: Term, dimensions: Dimensions): boolean
	for _, unit in term.units do
		if MetricUnitDimensionUtils.equal(unit.dimensions, dimensions) then
			return true
		end
	end
	return false
end

function MetricUnitParseUtils._bestDimensionsOf(term: Term): Dimensions?
	local best = term.units[1]
	return if best then best.dimensions else nil
end

function MetricUnitParseUtils._pickUnit(term: Term, dimensions: Dimensions?, text: string): (MeasuredUnit?, string?)
	for _, unit in term.units do
		if dimensions == nil or MetricUnitDimensionUtils.equal(unit.dimensions, dimensions) then
			return unit, nil
		end
	end
	return nil, MetricUnitParseUtils._mismatchMessage(term.units[1].dimensions, dimensions :: Dimensions, text)
end

function MetricUnitParseUtils._sumTerms(
	terms: { Term },
	dimensions: Dimensions?,
	text: string,
	expected: Expectation
): (MetricUnitData?, string?)
	local amount = 0
	local sumDimensions: Dimensions? = nil
	local signOfTheWhole = if terms[1].number < 0 then -1 else 1
	for _, term in terms do
		if term.unitText == "" then
			return nil, string.format("Add a unit to every number in %q", text)
		end
		local unit, err = MetricUnitParseUtils._pickUnit(term, dimensions, text)
		if not unit then
			return nil, err
		end
		local readingsArePoints = unit.zero ~= nil
		if readingsArePoints then
			return nil, string.format("Write a temperature as one number and unit, not %q", text)
		end
		amount += signOfTheWhole * math.abs(term.number) * unit.factor
		sumDimensions = unit.dimensions
	end

	return {
		amount = amount,
		dimensions = table.clone(sumDimensions :: Dimensions),
		absolute = if expected.absolute then true else nil,
	},
		nil
end

function MetricUnitParseUtils._unitData(number: number, unit: MeasuredUnit, expectedAbsolute: boolean?): MetricUnitData
	local dimensions = table.clone(unit.dimensions)
	local zero = unit.zero
	local isDifferenceExpected = expectedAbsolute == false
	if zero ~= nil and not isDifferenceExpected then
		return { amount = number * unit.factor + zero, dimensions = dimensions, absolute = true }
	end
	return { amount = number * unit.factor, dimensions = dimensions, absolute = if expectedAbsolute then true else nil }
end

function MetricUnitParseUtils._addUnitMessage(number: number, dimensions: Dimensions): string
	local unit = MetricUnitParseUtils._suggestedUnit(dimensions)
	if not unit then
		return string.format("Add a unit of %s", MetricUnitDimensionUtils.describe(dimensions))
	end
	local example = if UNSPACED_SYMBOLS[unit.symbol] then unit.symbol else " " .. unit.symbol
	return string.format('Add a unit, such as "%s%s"', MetricUnitFormatUtils.formatNumber(number), example)
end

function MetricUnitParseUtils._suggestedUnit(dimensions: Dimensions): UnitDefinition?
	local displayUnits = MetricUnitDisplayUnitUtils.getDisplayUnits(dimensions)
	if displayUnits then
		return MetricUnitDisplayUnitUtils.getBaseUnit(displayUnits)
	end
	local ids = MetricUnitDefinitions.getUnitIds(dimensions)
	return if ids[1] then MetricUnitDefinitions.getUnit(ids[1]) else nil
end

function MetricUnitParseUtils._checkKind(
	data: MetricUnitData,
	expected: Expectation,
	text: string
): (MetricUnitData?, string?)
	local expectedDimensions = expected.dimensions
	if expectedDimensions == nil then
		return data, nil
	end
	if not MetricUnitDimensionUtils.equal(data.dimensions, expectedDimensions) then
		return nil, MetricUnitParseUtils._mismatchMessage(data.dimensions, expectedDimensions, text)
	end

	local isAbsolute = data.absolute == true
	local isAbsoluteExpected = expected.absolute == true
	if isAbsolute ~= isAbsoluteExpected then
		return nil,
			string.format(
				"Expected %s, but %q is %s",
				MetricUnitKinds.describeKind(expectedDimensions, isAbsoluteExpected),
				text,
				MetricUnitKinds.describeKind(data.dimensions, isAbsolute)
			)
	end
	return data, nil
end

function MetricUnitParseUtils._mismatchMessage(got: Dimensions, expected: Dimensions, text: string): string
	return string.format(
		"Expected %s, but %q is %s",
		MetricUnitDimensionUtils.describe(expected),
		text,
		MetricUnitDimensionUtils.describe(got)
	)
end

return table.freeze(MetricUnitParseUtils)
