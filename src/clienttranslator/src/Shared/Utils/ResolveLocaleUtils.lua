--!strict
--[=[
	Shared locale-id parsing and resolution. Keeps the "given a locale like
	`en-us`, what do we actually use?" logic in one place so number formatting,
	dialog pacing, and any other locale-sensitive feature resolve identically.

	Locale ids follow BCP-47-ish shapes: a language subtag, then optional script
	and/or region subtags separated by `-` (or sometimes `_`), e.g. `en`, `en-us`,
	`pt-br`, `zh-Hant-TW`. Matching is case-insensitive.

	@class ResolveLocaleUtils
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

local ResolveLocaleUtils = {}

-- Chinese variant keys to prefer, in priority order, when routing to a caller's
-- available locale table. Traditional first-choices vs Simplified first-choices.
local TRADITIONAL_CHINESE_KEYS: { string } = Table.readonly({ "zh-tw", "zh-hant", "zh-hk", "zh-mo" })
local SIMPLIFIED_CHINESE_KEYS: { string } = Table.readonly({ "zh-cn", "zh-hans", "zh-sg", "zh" })

--[=[
	Returns the lowercased primary language subtag, or nil when the input has no
	language subtag (nil, non-string, empty, or leading punctuation/digits).

	```lua
	ResolveLocaleUtils.getLanguageSubtag("en-us") --> "en"
	ResolveLocaleUtils.getLanguageSubtag("zh_Hant_TW") --> "zh"
	ResolveLocaleUtils.getLanguageSubtag("PT-BR") --> "pt"
	ResolveLocaleUtils.getLanguageSubtag(nil) --> nil
	```

	@param locale string?
	@return string?
	@within ResolveLocaleUtils
]=]
function ResolveLocaleUtils.getLanguageSubtag(locale: string?): string?
	if type(locale) ~= "string" then
		return nil
	end

	-- Language subtags are letters only, so this stops at the first "-", "_" or digit.
	local languageSubtag = string.match(locale, "^%a+")
	if not languageSubtag then
		return nil
	end

	return string.lower(languageSubtag)
end

-- Regions written in Traditional Chinese. A `zh` locale that names one of these is
-- Traditional even without an explicit `hant` script subtag (`zh-tw`, `zh-hk`, `zh-mo`).
-- Frozen rather than Table.readonly: this is looked up with subtags that are usually not in
-- it, and Table.readonly raises on a missing index.
local TRADITIONAL_CHINESE_REGIONS: { [string]: boolean } = table.freeze({ tw = true, hk = true, mo = true })

-- Splits a locale into its lowercased subtags, accepting either separator. Returns nil when
-- there is nothing to split.
local function getSubtags(locale: string?): { string }?
	if type(locale) ~= "string" or locale == "" then
		return nil
	end

	local subtags = {}
	for subtag in string.gmatch(string.lower(locale), "[^-_]+") do
		table.insert(subtags, subtag)
	end

	if #subtags == 0 then
		return nil
	end

	return subtags
end

--[=[
	Returns the script subtag, or nil when the locale does not carry one. A script subtag is
	the four-letter subtag directly after the language (`zh-Hant`, `zh-Hant-TW`, `sr-Latn`);
	a two-letter or three-digit subtag in that position is a region, not a script.

	```lua
	ResolveLocaleUtils.getScriptSubtag("zh-Hant-TW") --> "hant"
	ResolveLocaleUtils.getScriptSubtag("zh-TW") --> nil
	```

	@param locale string?
	@return string?
	@within ResolveLocaleUtils
]=]
function ResolveLocaleUtils.getScriptSubtag(locale: string?): string?
	local subtags = getSubtags(locale)
	if not subtags then
		return nil
	end

	local candidate = subtags[2]
	if candidate and #candidate == 4 and string.match(candidate, "^%a+$") then
		return candidate
	end

	return nil
end

--[=[
	Whether a Chinese locale is Traditional. The `hant` script subtag, and the `tw` / `hk` /
	`mo` regions, are Traditional; everything else (`hans`, `cn`, `sg`, bare `zh`) is
	Simplified. Only meaningful for `zh` locales.

	@param locale string?
	@return boolean
	@within ResolveLocaleUtils
]=]
function ResolveLocaleUtils.isTraditionalChinese(locale: string?): boolean
	local subtags = getSubtags(locale)
	if not subtags then
		return false
	end

	-- Matched per subtag rather than as a substring, so a region only counts in the region
	-- position -- and so `_` separators are read the same as `-`.
	for index = 2, #subtags do
		local subtag = subtags[index]
		if subtag == "hant" then
			return true
		elseif subtag == "hans" then
			return false
		elseif TRADITIONAL_CHINESE_REGIONS[subtag] then
			return true
		end
	end

	return false
end

--[=[
	Whether two locales are close enough that one can be read in place of the other: the same
	language, written in the same script.

	Regional variants of a language substitute for one another, so `es-mx` reads `es-es` and
	`en-gb` reads `en-us`. Scripts do not: Traditional and Simplified Chinese are not mutually
	readable, so `zh-tw` never reads `zh-cn`, whether the script is spelled out (`zh-Hant` vs
	`zh-Hans`) or implied by region (`zh-tw` vs `zh-cn`). The same holds for any language
	whose locales carry differing script subtags, such as `sr-Latn` and `sr-Cyrl`.

	```lua
	ResolveLocaleUtils.isCompatibleLocale("es-mx", "es-es") --> true
	ResolveLocaleUtils.isCompatibleLocale("zh-tw", "zh-cn") --> false
	ResolveLocaleUtils.isCompatibleLocale("pt-br", "en-us") --> false
	```

	@param locale string?
	@param otherLocale string?
	@return boolean
	@within ResolveLocaleUtils
]=]
function ResolveLocaleUtils.isCompatibleLocale(locale: string?, otherLocale: string?): boolean
	local languageSubtag = ResolveLocaleUtils.getLanguageSubtag(locale)
	local otherLanguageSubtag = ResolveLocaleUtils.getLanguageSubtag(otherLocale)

	if not languageSubtag or not otherLanguageSubtag or languageSubtag ~= otherLanguageSubtag then
		return false
	end

	-- Chinese carries its script in the region as often as in a script subtag, so it needs
	-- the dedicated check rather than the generic one below.
	if languageSubtag == "zh" then
		return ResolveLocaleUtils.isTraditionalChinese(locale) == ResolveLocaleUtils.isTraditionalChinese(otherLocale)
	end

	-- Only when both name a script: a bare `sr` is readable as either, and demanding a match
	-- would break the regional fallback this exists to preserve.
	local script = ResolveLocaleUtils.getScriptSubtag(locale)
	local otherScript = ResolveLocaleUtils.getScriptSubtag(otherLocale)
	if script and otherScript and script ~= otherScript then
		return false
	end

	return true
end

--[=[
	Resolves a locale to the best-matching key present in `availableLocales`:

	1. Exact (case-insensitive) match.
	2. Chinese Traditional/Simplified routing to whichever variant keys exist.
	3. Closest key sharing the language subtag (smallest key, so the pick is
	   deterministic), so e.g. `en-gb` falls back to `en-us` and `es-mx` to `es-es`
	   rather than to an unrelated default.

	Returns nil when nothing shares the language subtag; callers apply their own
	default in that case.

	@param locale string?
	@param availableLocales { [string]: T }
	@return string?
	@within ResolveLocaleUtils
]=]
function ResolveLocaleUtils.resolveClosestKey<T>(locale: string?, availableLocales: { [string]: T }): string?
	if type(locale) ~= "string" or locale == "" then
		return nil
	end

	local lowered = string.lower(locale)

	if availableLocales[lowered] ~= nil then
		return lowered
	end

	local languageSubtag = ResolveLocaleUtils.getLanguageSubtag(lowered) or lowered

	-- Chinese: pick Traditional or Simplified, preferring whichever key the caller
	-- actually defines. Fall through to the generic search if none are present.
	if languageSubtag == "zh" then
		local preferred: { string } = if ResolveLocaleUtils.isTraditionalChinese(lowered)
			then TRADITIONAL_CHINESE_KEYS
			else SIMPLIFIED_CHINESE_KEYS

		for _, key in preferred do
			if availableLocales[key] ~= nil then
				return key
			end
		end
	end

	-- Closest entry sharing the language subtag (smallest key, so the pick is deterministic).
	local closest: string? = nil
	for key in availableLocales do
		if ResolveLocaleUtils.getLanguageSubtag(key) == languageSubtag and (closest == nil or key < closest) then
			closest = key
		end
	end

	return closest
end

return ResolveLocaleUtils
