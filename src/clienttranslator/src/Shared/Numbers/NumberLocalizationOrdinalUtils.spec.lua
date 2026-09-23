--!strict
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local NumberLocalizationOrdinalUtils = require("NumberLocalizationOrdinalUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function checkOrdinal(locale: string, responseMapping: { [number]: string })
	for input, output in responseMapping do
		expect(NumberLocalizationOrdinalUtils.localize(input, locale)).toBe(output)
	end
end

describe("NumberLocalizationOrdinalUtils.localize", function()
	it("should use st, nd, rd and th in English, including the teens", function()
		checkOrdinal("en-us", {
			[0] = "0th",
			[1] = "1st",
			[2] = "2nd",
			[3] = "3rd",
			[4] = "4th",
			[11] = "11th",
			[12] = "12th",
			[13] = "13th",
			[21] = "21st",
			[22] = "22nd",
			[23] = "23rd",
			[101] = "101st",
			[111] = "111th",
			[112] = "112th",
		})
	end)

	it("should use er for 1 and e otherwise in French", function()
		checkOrdinal("fr-fr", { [1] = "1er", [2] = "2e", [21] = "21e", [22] = "22e" })
	end)

	it("should use the ordinal indicator in Spanish, Portuguese and Italian", function()
		checkOrdinal("es-es", { [1] = "1º", [22] = "22º" })
		checkOrdinal("pt-br", { [1] = "1º", [22] = "22º" })
		checkOrdinal("it-it", { [1] = "1º", [22] = "22º" })
	end)

	it("should use a trailing period in German, Polish and Turkish", function()
		checkOrdinal("de-de", { [1] = "1.", [22] = "22." })
		checkOrdinal("pl-pl", { [1] = "1.", [22] = "22." })
		checkOrdinal("tr-tr", { [1] = "1.", [22] = "22." })
	end)

	it("should use e in Dutch and :a / :e in Swedish", function()
		checkOrdinal("nl-nl", { [1] = "1e", [22] = "22e" })
		checkOrdinal("sv-se", { [1] = "1:a", [2] = "2:a", [3] = "3:e", [11] = "11:e", [12] = "12:e", [21] = "21:a" })
	end)

	it("should prefix in Chinese, Japanese and Korean", function()
		checkOrdinal("zh-cn", { [1] = "第1", [22] = "第22" })
		checkOrdinal("zh-tw", { [22] = "第22" })
		checkOrdinal("ja-jp", { [22] = "第22" })
		checkOrdinal("ko-kr", { [22] = "제22" })
	end)

	it("should cover the remaining NumberLocalizationUtils languages", function()
		checkOrdinal("ru-ru", { [1] = "1-й", [22] = "22-й" })
		checkOrdinal("id-id", { [22] = "ke-22" })
		checkOrdinal("vi-vn", { [22] = "thứ 22" })
		checkOrdinal("th-th", { [22] = "ที่ 22" })
		checkOrdinal("ar", { [22] = "22" })
	end)

	it("should resolve regional variants to their language", function()
		checkOrdinal("en-gb", { [22] = "22nd" })
		checkOrdinal("es-mx", { [22] = "22º" })
		checkOrdinal("fr-ca", { [1] = "1er" })
	end)

	it("should fall back to English for an unknown locale", function()
		checkOrdinal("xx-yy", { [22] = "22nd" })
	end)
end)

describe("NumberLocalizationOrdinalUtils.getSuffix", function()
	it("should return only the suffix", function()
		expect(NumberLocalizationOrdinalUtils.getSuffix(22, "en-us")).toBe("nd")
		expect(NumberLocalizationOrdinalUtils.getSuffix(1, "fr-fr")).toBe("er")
		expect(NumberLocalizationOrdinalUtils.getSuffix(22, "de-de")).toBe(".")
		expect(NumberLocalizationOrdinalUtils.getSuffix(22, "zh-cn")).toBe("")
	end)
end)
