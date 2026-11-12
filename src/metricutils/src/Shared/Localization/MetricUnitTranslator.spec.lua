--!strict
--[[
	@class MetricUnitTranslator.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnit = require("MetricUnit")
local MetricUnitDefinitions = require("MetricUnitDefinitions")
local MetricUnitFallbackStrings = require("MetricUnitFallbackStrings")
local MetricUnitFormatUtils = require("MetricUnitFormatUtils")
local PluralCategoryUtils = require("PluralCategoryUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local NB = MetricUnitFormatUtils.NO_BREAK_SPACE
local CATEGORIES = { "zero", "one", "two", "few", "many", "other" }
local LANGUAGES =
	{ "en", "es", "fr", "de", "pt", "it", "ru", "pl", "tr", "id", "vi", "th", "ar", "zh-cn", "zh-tw", "ja", "ko" }

-- A number in each plural category the language uses, as CLDR's samples give them
local SAMPLES: { [string]: { [string]: number } } = {
	en = { one = 1, other = 2 },
	es = { one = 1, many = 1000000, other = 2 },
	fr = { one = 1, many = 1000000, other = 2 },
	de = { one = 1, other = 2 },
	pt = { one = 1, many = 1000000, other = 2 },
	it = { one = 1, many = 1000000, other = 2 },
	ru = { one = 1, few = 2, many = 5, other = 1.5 },
	pl = { one = 1, few = 2, many = 5, other = 1.5 },
	tr = { one = 1, other = 2 },
	id = { other = 1 },
	vi = { one = 1, other = 2 },
	th = { other = 1 },
	ar = { zero = 0, one = 1, two = 2, few = 3, many = 11, other = 100 },
	["zh-cn"] = { other = 1 },
	["zh-tw"] = { other = 1 },
	ja = { other = 1 },
	ko = { other = 1 },
}

-- The locale files are StringValues under the translator module, so these read them in Roblox only
local function readLocale(language: string): any?
	if typeof(script) ~= "Instance" then
		return nil
	end
	local folder = (script :: any).Parent:FindFirstChild("MetricUnitTranslator")
	local file = folder and folder:FindFirstChild(language .. ".json")
	if not file then
		return nil
	end
	return game:GetService("HttpService"):JSONDecode(file.Value)
end

-- A translator over one decoded locale file, for formatting every locale without streaming it
local function fileTranslator(language: string, data: any): any
	local function lookup(key: string): string?
		local node = data
		for part in string.gmatch(key, "[^%.]+") do
			node = if type(node) == "table" then node[part] else nil
		end
		return if type(node) == "string" then node else nil
	end
	return {
		GetLocaleId = function()
			return language
		end,
		FormatByKey = function(_self: any, key: string, args: { [string]: any }?): string
			local text = lookup(key)
			if not text then
				error("No key " .. key)
			end
			return (string.gsub(text, "{(%a+)}", function(name)
				return (args :: any)[name]
			end))
		end,
		ObserveFormatByKey = function()
			error("unused")
		end,
	}
end

local function substitute(template: string, numberText: string): string
	return (string.gsub(template, "{n}", function()
		return numberText
	end))
end

describe("MetricUnitTranslator locale files", function()
	it("ships every locale, each with every key the English source has, long and short", function()
		local english = readLocale("en")
		if english == nil then
			return
		end
		for _, language in LANGUAGES do
			local locale = readLocale(language)
			assert(locale, string.format("No locale file for %s", language))
			for id in english.units do
				local entry = locale.units[id]
				assert(entry, string.format("%s has no units.%s", language, id))
				for _, display in { "long", "short" } do
					for _, category in CATEGORIES do
						local text = entry[display] and entry[display][category]
						if type(text) ~= "string" or text == "" then
							error(string.format("%s has no units.%s.%s.%s", language, id, display, category))
						end
					end
				end
			end
			for name in english.prefixes do
				for _, display in { "long", "short" } do
					local text = locale.prefixes[name] and locale.prefixes[name][display]
					if type(text) ~= "string" or string.find(text, "{unit}", 1, true) == nil then
						error(string.format("%s has no prefixes.%s.%s", language, name, display))
					end
				end
			end
			for id in english.per do
				for _, display in { "long", "short" } do
					local text = locale.per[id] and locale.per[id][display]
					if type(text) ~= "string" or string.find(text, "{n}", 1, true) == nil then
						error(string.format("%s has no per.%s.%s", language, id, display))
					end
				end
			end
		end
	end)

	it("has an English source that matches the definitions' names and symbols, and every prefix", function()
		local english = readLocale("en")
		if english == nil then
			return
		end
		local named: { [string]: boolean } = {}
		for _, unit in MetricUnitDefinitions.getUnits() do
			local names = unit.names
			local entry = english.units[unit.id]
			local composedFromItsPrefix = unit.prefix ~= nil and entry == nil
			if names and not composedFromItsPrefix then
				named[unit.id] = true
				assert(entry, string.format("en.json has no key for %s", unit.id))
				local fallback = MetricUnitFallbackStrings.getUnitStringsForLocale("en-us")[unit.id] :: any
				for _, category in CATEGORIES do
					local isOne = category == "one"
					expect(entry.long[category]).toBe("{n}" .. NB .. (if isOne then names.one else names.other))
					local short = if isOne then fallback.short.one else fallback.short.other
					expect(entry.short[category]).toBe((string.gsub(short, "%%s", "{n}")))
				end
			end
		end
		for id in english.units do
			expect(named[id]).toBe(true)
		end
		for _, prefix in MetricUnitDefinitions.getPrefixes() do
			expect(english.prefixes[prefix.name]).toEqual({
				long = prefix.name .. "{unit}",
				short = prefix.symbol .. "{unit}",
			})
		end
		for id, phrases in english.per do
			local unit = MetricUnitDefinitions.getUnit(id)
			assert(unit, id)
			expect(phrases.long).toBe("{n} per " .. id)
			expect(phrases.short).toBe("{n}/" .. unit.symbol)
		end
	end)

	it("formats a sample in every plural category of every locale", function()
		for _, language in LANGUAGES do
			local data = readLocale(language)
			if data == nil then
				return
			end
			local translator = fileTranslator(language, data)
			for category, sample in SAMPLES[language] do
				expect(PluralCategoryUtils.getPluralCategory(language, sample, nil)).toBe(category)
				local numberText = MetricUnitFormatUtils.formatNumber(sample, { locale = language })
				for _, display in { "long", "short" } do
					local options: MetricUnit.FormatOptions =
						{ unit = "kilometer", unitDisplay = display :: any, translator = translator }
					local expected = substitute(data.units.kilometer[display][category], numberText)
					expect(MetricUnit.format(MetricUnit.kilometers(sample), options)).toBe(expected)
				end
			end
		end
	end)

	it("writes a prefixed unit from its prefix and the unit's own name", function()
		local expectations: { [string]: { string } } = {
			de = { "5 Kilovolt", "5 kV", "3 Nanometer" },
			fr = { "5 kilovolts", "5 kV", "3 nanomètres" },
			ru = { "5 киловольт", "5 кВ", "3 нанометра" },
			ja = { "5 キロボルト", "5 kV", "3 ナノメートル" },
		}
		for language, expected in expectations do
			local data = readLocale(language)
			if data == nil then
				return
			end
			local translator = fileTranslator(language, data)
			local function write(value: MetricUnit.MetricUnit, unit: string, display: string): string
				local options: any = { unit = unit, unitDisplay = display, translator = translator, locale = language }
				return (string.gsub(MetricUnit.format(value, options), NB, " "))
			end
			expect(data.units.kilovolt).toBeNil()
			expect(write(MetricUnit.new(5000, "volt"), "kilovolt", "long")).toBe(expected[1])
			expect(write(MetricUnit.new(5000, "volt"), "kilovolt", "short")).toBe(expected[2])
			expect(write(MetricUnit.new(3, "nanometer" :: any), "nanometer", "long")).toBe(expected[3])
		end
	end)

	it("writes rates per a time unit in the translator's language", function()
		local data = readLocale("ru")
		if data == nil then
			return
		end
		local options: MetricUnit.FormatOptions = {
			unit = "kilometer",
			perUnit = "hour",
			translator = fileTranslator("ru", data),
		}
		local numerator = substitute(data.units.kilometer.short.many, "5")
		expect(MetricUnit.format(MetricUnit.new(5, "kilometerPerHour"), options)).toBe(
			substitute(data.per.hour.short, numerator)
		)
	end)
end)

describe("MetricUnitTranslator", function()
	local function streamed(language: string, check: (translator: any, data: any) -> ())
		if typeof(script) ~= "Instance" then
			return
		end
		local TranslatorTestUtils = require("TranslatorTestUtils")
		local controller = TranslatorTestUtils.setup()
		controller.setForcedLocaleId(language)
		local folder = (script :: any).Parent.MetricUnitTranslator
		local translator = controller.awaitLoaded(controller.newTranslatorFromInstance(folder))
		controller.awaitEntriesWritten()
		check(translator, readLocale(language))
		controller:Destroy()
	end

	it("streams Spanish names to MetricUnit.format through a real translator", function()
		streamed("es", function(translator)
			local options: MetricUnit.FormatOptions = { unitDisplay = "long", translator = translator }
			expect(MetricUnit.format(MetricUnit.new(3, "mile"):ToUSCustomary(), options)).toBe("3" .. NB .. "millas")
			expect(MetricUnit.format(MetricUnit.kilometers(1), options)).toBe("1" .. NB .. "kilómetro")
		end)
	end)

	for _, language in { "ar", "ru", "ja" } do
		it(
			string.format("streams %s through a real translator, long and short, in every plural category", language),
			function()
				streamed(language, function(translator, data)
					for category, sample in SAMPLES[language] do
						local numberText = MetricUnitFormatUtils.formatNumber(sample, { locale = language })
						for _, display in { "long", "short" } do
							local options: MetricUnit.FormatOptions =
								{ unit = "kilometer", unitDisplay = display :: any, translator = translator }
							local expected = substitute(data.units.kilometer[display][category], numberText)
							expect(MetricUnit.format(MetricUnit.kilometers(sample), options)).toBe(expected)
						end
					end
				end)
			end
		)
	end
end)

describe("No-break spaces", function()
	it("join a number to its unit", function()
		expect(MetricUnit.format(MetricUnit.kilometers(5))).toBe("5" .. NB .. "km")
		expect(MetricUnit.format(MetricUnit.kilometers(5), { unitDisplay = "long" })).toBe("5" .. NB .. "kilometers")
		expect(MetricUnit.format(MetricUnit.minutes(90))).toBe("1" .. NB .. "hour, 30" .. NB .. "minutes")
		expect(MetricUnit.format(MetricUnit.percent(45), { unit = "percent" })).toBe("45%")
		expect((MetricUnit.parse("5" .. NB .. "km") :: any):In("meter")).toBe(5000)
	end)

	it("measure as wide as a space in Roblox's fonts", function()
		local dataModel: any = game
		if typeof(dataModel) ~= "Instance" then
			return
		end
		local TextService = (dataModel :: any):GetService("TextService")
		local bounds = Vector2.new(1000, 100)
		for _, font in { Enum.Font.SourceSans, Enum.Font.Gotham, Enum.Font.Arial } do
			local plainWidth = TextService:GetTextSize("5 km", 18, font, bounds).X
			local noBreakWidth = TextService:GetTextSize("5" .. NB .. "km", 18, font, bounds).X
			expect(noBreakWidth).toBe(plainWidth)
		end
	end)
end)

describe("MetricUnitFormatUtils.formatUnit with a translator", function()
	it("takes its locale from the translator, for numbers and plural forms", function()
		local data = readLocale("ru")
		if data == nil then
			return
		end
		local translator = fileTranslator("ru", data)
		local text = MetricUnitFormatUtils.formatUnit("meter", 3, { translator = translator, unitDisplay = "long" })
		expect(text).toBe(substitute(data.units.meter.long.few, "3"))
	end)
end)
