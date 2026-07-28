--!strict
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local ResolveLocaleUtils = require("ResolveLocaleUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("ResolveLocaleUtils.getLanguageSubtag", function()
	it("extracts the language subtag, lowercased", function()
		expect(ResolveLocaleUtils.getLanguageSubtag("en")).toBe("en")
		expect(ResolveLocaleUtils.getLanguageSubtag("en-us")).toBe("en")
		expect(ResolveLocaleUtils.getLanguageSubtag("EN-GB")).toBe("en")
		expect(ResolveLocaleUtils.getLanguageSubtag("pt-br")).toBe("pt")
	end)

	it("handles script + region subtags and underscore separators", function()
		expect(ResolveLocaleUtils.getLanguageSubtag("zh-Hant-TW")).toBe("zh")
		expect(ResolveLocaleUtils.getLanguageSubtag("zh_CN")).toBe("zh")
	end)

	it("returns nil when there is no language subtag", function()
		expect(ResolveLocaleUtils.getLanguageSubtag(nil)).toBe(nil)
		expect(ResolveLocaleUtils.getLanguageSubtag("")).toBe(nil)
		expect(ResolveLocaleUtils.getLanguageSubtag("123")).toBe(nil)
		expect(ResolveLocaleUtils.getLanguageSubtag("-us")).toBe(nil)
	end)
end)

describe("ResolveLocaleUtils.isTraditionalChinese", function()
	it("treats hant / tw / hk / mo as Traditional", function()
		expect(ResolveLocaleUtils.isTraditionalChinese("zh-hant")).toBe(true)
		expect(ResolveLocaleUtils.isTraditionalChinese("zh-TW")).toBe(true)
		expect(ResolveLocaleUtils.isTraditionalChinese("zh-hk")).toBe(true)
		expect(ResolveLocaleUtils.isTraditionalChinese("zh-mo")).toBe(true)
		expect(ResolveLocaleUtils.isTraditionalChinese("zh-Hant-HK")).toBe(true)
	end)

	it("treats hans / cn / sg / bare zh as Simplified", function()
		expect(ResolveLocaleUtils.isTraditionalChinese("zh")).toBe(false)
		expect(ResolveLocaleUtils.isTraditionalChinese("zh-cn")).toBe(false)
		expect(ResolveLocaleUtils.isTraditionalChinese("zh-hans")).toBe(false)
		expect(ResolveLocaleUtils.isTraditionalChinese("zh-sg")).toBe(false)
	end)

	it("reads underscore separators the same as dashes", function()
		expect(ResolveLocaleUtils.isTraditionalChinese("zh_TW")).toBe(true)
		expect(ResolveLocaleUtils.isTraditionalChinese("zh_Hant_TW")).toBe(true)
		expect(ResolveLocaleUtils.isTraditionalChinese("zh_CN")).toBe(false)
	end)

	it("matches a region only in the region position", function()
		expect(ResolveLocaleUtils.isTraditionalChinese("tw")).toBe(false)
		expect(ResolveLocaleUtils.isTraditionalChinese("mo-cn")).toBe(false)
	end)

	it("prefers an explicit script over the region", function()
		expect(ResolveLocaleUtils.isTraditionalChinese("zh-Hans-TW")).toBe(false)
		expect(ResolveLocaleUtils.isTraditionalChinese("zh-Hant-CN")).toBe(true)
	end)

	it("is false for non-strings", function()
		expect(ResolveLocaleUtils.isTraditionalChinese(nil)).toBe(false)
	end)
end)

describe("ResolveLocaleUtils.getScriptSubtag", function()
	it("reads the four-letter subtag after the language", function()
		expect(ResolveLocaleUtils.getScriptSubtag("zh-Hant")).toBe("hant")
		expect(ResolveLocaleUtils.getScriptSubtag("zh-Hant-TW")).toBe("hant")
		expect(ResolveLocaleUtils.getScriptSubtag("sr_Latn_RS")).toBe("latn")
	end)

	it("does not mistake a region for a script", function()
		expect(ResolveLocaleUtils.getScriptSubtag("zh-TW")).toBe(nil)
		expect(ResolveLocaleUtils.getScriptSubtag("en-us")).toBe(nil)
		expect(ResolveLocaleUtils.getScriptSubtag("es-419")).toBe(nil)
		expect(ResolveLocaleUtils.getScriptSubtag("zh")).toBe(nil)
		expect(ResolveLocaleUtils.getScriptSubtag(nil)).toBe(nil)
	end)
end)

describe("ResolveLocaleUtils.isCompatibleLocale", function()
	it("substitutes regional variants of the same language", function()
		expect(ResolveLocaleUtils.isCompatibleLocale("es-mx", "es-es")).toBe(true)
		expect(ResolveLocaleUtils.isCompatibleLocale("es-es", "es-mx")).toBe(true)
		expect(ResolveLocaleUtils.isCompatibleLocale("es", "es-mx")).toBe(true)
		expect(ResolveLocaleUtils.isCompatibleLocale("es-mx", "es")).toBe(true)
		expect(ResolveLocaleUtils.isCompatibleLocale("en-gb", "en-us")).toBe(true)
		expect(ResolveLocaleUtils.isCompatibleLocale("pt-br", "pt-pt")).toBe(true)
	end)

	it("never substitutes across languages", function()
		expect(ResolveLocaleUtils.isCompatibleLocale("es-mx", "en-us")).toBe(false)
		expect(ResolveLocaleUtils.isCompatibleLocale("pt-br", "es-es")).toBe(false)
	end)

	it("never substitutes Traditional and Simplified Chinese, however they are spelled", function()
		expect(ResolveLocaleUtils.isCompatibleLocale("zh-tw", "zh-cn")).toBe(false)
		expect(ResolveLocaleUtils.isCompatibleLocale("zh-cn", "zh-tw")).toBe(false)
		expect(ResolveLocaleUtils.isCompatibleLocale("zh-hant", "zh-hans")).toBe(false)
		expect(ResolveLocaleUtils.isCompatibleLocale("zh-Hant-TW", "zh-CN")).toBe(false)
		expect(ResolveLocaleUtils.isCompatibleLocale("zh-hk", "zh-sg")).toBe(false)
		expect(ResolveLocaleUtils.isCompatibleLocale("zh-mo", "zh")).toBe(false)
		expect(ResolveLocaleUtils.isCompatibleLocale("zh_Hant_TW", "zh_CN")).toBe(false)
	end)

	it("substitutes Chinese locales written in the same script", function()
		expect(ResolveLocaleUtils.isCompatibleLocale("zh-tw", "zh-hk")).toBe(true)
		expect(ResolveLocaleUtils.isCompatibleLocale("zh-hant", "zh-tw")).toBe(true)
		expect(ResolveLocaleUtils.isCompatibleLocale("zh-cn", "zh-sg")).toBe(true)
		expect(ResolveLocaleUtils.isCompatibleLocale("zh", "zh-hans")).toBe(true)
	end)

	it("never substitutes across explicit scripts in any language", function()
		expect(ResolveLocaleUtils.isCompatibleLocale("sr-Latn", "sr-Cyrl")).toBe(false)
		expect(ResolveLocaleUtils.isCompatibleLocale("sr-Latn", "sr-Latn-RS")).toBe(true)
	end)

	it("substitutes when only one side names a script, since a bare locale reads as either", function()
		expect(ResolveLocaleUtils.isCompatibleLocale("sr", "sr-Cyrl")).toBe(true)
		expect(ResolveLocaleUtils.isCompatibleLocale("sr-Latn", "sr")).toBe(true)
	end)

	it("is false when either locale is missing or has no language subtag", function()
		expect(ResolveLocaleUtils.isCompatibleLocale(nil, "en-us")).toBe(false)
		expect(ResolveLocaleUtils.isCompatibleLocale("en-us", nil)).toBe(false)
		expect(ResolveLocaleUtils.isCompatibleLocale("", "en-us")).toBe(false)
		expect(ResolveLocaleUtils.isCompatibleLocale("en-us", "")).toBe(false)
		expect(ResolveLocaleUtils.isCompatibleLocale("419", "en-us")).toBe(false)
	end)
end)

describe("ResolveLocaleUtils.resolveClosestKey", function()
	local available = {
		["en-us"] = true,
		["es-es"] = true,
		["zh-cn"] = true,
		["zh-tw"] = true,
		["ar"] = true,
	}

	it("matches an exact key case-insensitively", function()
		expect(ResolveLocaleUtils.resolveClosestKey("en-us", available)).toBe("en-us")
		expect(ResolveLocaleUtils.resolveClosestKey("EN-US", available)).toBe("en-us")
		expect(ResolveLocaleUtils.resolveClosestKey("ar", available)).toBe("ar")
	end)

	it("falls back a regional variant to its closest same-language key", function()
		expect(ResolveLocaleUtils.resolveClosestKey("en-gb", available)).toBe("en-us")
		expect(ResolveLocaleUtils.resolveClosestKey("es-mx", available)).toBe("es-es")
	end)

	it("routes Chinese to Simplified or Traditional variant keys", function()
		expect(ResolveLocaleUtils.resolveClosestKey("zh-hans", available)).toBe("zh-cn")
		expect(ResolveLocaleUtils.resolveClosestKey("zh", available)).toBe("zh-cn")
		expect(ResolveLocaleUtils.resolveClosestKey("zh-hant", available)).toBe("zh-tw")
		expect(ResolveLocaleUtils.resolveClosestKey("zh-hk", available)).toBe("zh-tw")
	end)

	it("returns nil when nothing shares the language subtag", function()
		expect(ResolveLocaleUtils.resolveClosestKey("de-de", available)).toBe(nil)
		expect(ResolveLocaleUtils.resolveClosestKey(nil, available)).toBe(nil)
		expect(ResolveLocaleUtils.resolveClosestKey("", available)).toBe(nil)
	end)

	it("prefers whichever Chinese variant key the caller actually defines", function()
		local simplifiedOnly = { ["zh-cn"] = true }
		expect(ResolveLocaleUtils.resolveClosestKey("zh-tw", simplifiedOnly)).toBe("zh-cn")
	end)
end)
