--!strict
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local NumberLocalizationUtils = require("NumberLocalizationUtils")
local RoundingBehaviourTypes = require("RoundingBehaviourTypes")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function checkLocale(locale: string, responseMapping)
	for input, output in responseMapping do
		expect(NumberLocalizationUtils.localize(input, locale)).toBe(output)
	end
end

local function checkValid_en_zh(locale: string)
	checkLocale(locale, {
		[0] = "0",
		[1] = "1",
		[25] = "25",
		[364] = "364",
		[4120] = "4,120",
		[57860] = "57,860",
		[624390] = "624,390",
		[7857000] = "7,857,000",
		[-12345678] = "-12,345,678",
		[23987.45678] = "23,987.45678",
		[-12.3456] = "-12.3456",
		[-23987.45678] = "-23,987.45678",
	})
end

describe("NumberLocalizationUtils.localize", function()
	-- it("should default to en-us when locale is not recognized", function()
	-- 	local logs = Logging.capture(function()
	-- 		checkValid_en_zh("bad_locale")
	-- 	end)
	-- 	expect(string.match(logs.warnings[1], "^Warning: Locale not found:") ~= nil).toBe(true)
	-- end)

	-- it("should default to en-us when locale is nil", function()
	-- 	local logs = Logging.capture(function()
	-- 		checkValid_en_zh(nil)
	-- 	end)
	-- 	expect(string.match(logs.warnings[1], "^Warning: Locale not found:") ~= nil).toBe(true)
	-- end)

	-- it("should default to en-us when locale is empty", function()
	-- 	local logs = Logging.capture(function()
	-- 		checkValid_en_zh("")
	-- 	end)
	-- 	expect(string.match(logs.warnings[1], "^Warning: Locale not found:") ~= nil).toBe(true)
	-- end)

	it("should localize correctly. (en-us)", function()
		checkValid_en_zh("en-us")
	end)

	it("should localize correctly. (en-gb)", function()
		checkValid_en_zh("en-gb")
	end)

	it("should localize correctly. (zh-cn)", function()
		checkValid_en_zh("zh-cn")
	end)

	it("should localize correctly. (zh-tw)", function()
		checkValid_en_zh("zh-tw")
	end)

	it("should localize a newly added language (pl-pl, space grouping)", function()
		checkLocale("pl-pl", {
			[4120] = "4 120",
			[57860] = "57 860",
			[624390] = "624 390",
			[7857000] = "7 857 000",
		})
	end)

	it("should localize a newly added language (ar)", function()
		checkLocale("ar", {
			[4120] = "4,120",
			[57860] = "57,860",
			[7857000] = "7,857,000",
		})
	end)

	it("should fall back a regional variant to its closest same-language entry", function()
		checkLocale("es-mx", { [7857000] = "7.857.000" }) -- -> es-es (group ".")
		checkLocale("es-419", { [7857000] = "7.857.000" }) -- -> es-es
		checkLocale("pt-pt", { [7857000] = "7.857.000" }) -- -> pt-br (group ".")
		checkLocale("fr-ca", { [7857000] = "7 857 000" }) -- -> fr-fr (group " ")
		checkLocale("de-at", { [7857000] = "7 857 000" }) -- -> de-de (group " ")
		checkLocale("en-gb", { [7857000] = "7,857,000" }) -- -> en-us (group ",")
		checkLocale("ar-sa", { [7857000] = "7,857,000" }) -- -> ar (group ",")
	end)
end)

describe("NumberLocalizationUtils.abbreviate", function()
	it("should round towards zero when using RoundingBehaviourTypes.Truncate", function()
		local roundToZeroMap = {
			[0] = "0",
			[1] = "1",
			[25] = "25",
			[364] = "364",
			[4120] = "4.12K",
			[57860] = "57.8K",
			[624390] = "624K",
			[999999] = "999K",
			[7857000] = "7.85M",
			[8e7] = "80M",
			[9e8] = "900M",
			[1e9] = "1B",
			[1e12] = "1,000B",
			[-0] = "0",
			[-1] = "-1",
			[-25] = "-25",
			[-364] = "-364",
			[-4120] = "-4.1K",
			[-57860] = "-57.8K",
			[-624390] = "-624K",
			[-999999] = "-999K",
			[-7857000] = "-7.8M",
			[-8e7] = "-80M",
			[-9e8] = "-900M",
			[-1e9] = "-1B",
			[-1e12] = "-1,000B",
			[1.1] = "1.1",
			[1499.99] = "1.49K",
			[-1.1] = "-1.1",
			[-1499.99] = "-1.4K",
		}

		for input, output in roundToZeroMap do
			expect(NumberLocalizationUtils.abbreviate(input, "en-us", RoundingBehaviourTypes.TRUNCATE)).toBe(output)
		end
	end)

	local function checkAbbrev(locale: string, responseMapping)
		for input, output in responseMapping do
			expect(NumberLocalizationUtils.abbreviate(input, locale, RoundingBehaviourTypes.TRUNCATE)).toBe(output)
		end
	end

	it("should abbreviate with the suffixes of a newly added language (pl-pl)", function()
		checkAbbrev("pl-pl", {
			[1500] = "1,5 tys.",
			[57860] = "57,8 tys.",
			[50000] = "50 tys.",
			[2500000] = "2,5 mln",
			[1e9] = "1 mld",
		})
	end)

	it("should abbreviate with Arabic suffixes (ar)", function()
		checkAbbrev("ar", {
			[1500] = "1.5 ألف",
			[2500000] = "2.5 مليون",
			[1e9] = "1 مليار",
		})
	end)

	it("should choose Chinese Simplified vs Traditional by script/region subtag", function()
		checkAbbrev("zh-hans", { [50000] = "5万", [1e9] = "10亿" })
		checkAbbrev("zh-cn", { [50000] = "5万", [1e9] = "10亿" })
		checkAbbrev("zh-hant", { [50000] = "5萬", [1e9] = "10億" })
		checkAbbrev("zh-tw", { [50000] = "5萬", [1e9] = "10億" })
		checkAbbrev("zh-hk", { [50000] = "5萬" }) -- Hong Kong -> Traditional
	end)

	it("should abbreviate a regional variant like its base language (es-mx == es-es)", function()
		for _, input in { 1500, 57860, 2500000, 50000, 1e9 } do
			expect(NumberLocalizationUtils.abbreviate(input, "es-mx", RoundingBehaviourTypes.TRUNCATE)).toBe(
				NumberLocalizationUtils.abbreviate(input, "es-es", RoundingBehaviourTypes.TRUNCATE)
			)
		end
	end)
end)
