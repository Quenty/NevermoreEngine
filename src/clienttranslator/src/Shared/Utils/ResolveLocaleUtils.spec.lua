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

	it("is false for non-strings", function()
		expect(ResolveLocaleUtils.isTraditionalChinese(nil)).toBe(false)
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
		-- en-gb has no exact entry, so it should resolve to en-us (same language),
		-- NOT to some unrelated default.
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
		-- Only a Simplified key exists here; a Traditional request still resolves to
		-- it rather than returning nil, because it shares the language.
		local simplifiedOnly = { ["zh-cn"] = true }
		expect(ResolveLocaleUtils.resolveClosestKey("zh-tw", simplifiedOnly)).toBe("zh-cn")
	end)
end)
