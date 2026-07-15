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

--[=[
	Whether a Chinese locale is Traditional. `hant`, and the `tw` / `hk` / `mo`
	regions are Traditional; everything else (`hans`, `cn`, `sg`, bare `zh`) is
	Simplified. Only meaningful for `zh` locales.

	@param locale string?
	@return boolean
	@within ResolveLocaleUtils
]=]
function ResolveLocaleUtils.isTraditionalChinese(locale: string?): boolean
	if type(locale) ~= "string" then
		return false
	end

	local lowered = string.lower(locale)
	return string.find(lowered, "hant", 1, true) ~= nil
		or string.find(lowered, "-tw", 1, true) ~= nil
		or string.find(lowered, "-hk", 1, true) ~= nil
		or string.find(lowered, "-mo", 1, true) ~= nil
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
