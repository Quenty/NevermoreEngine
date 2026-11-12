--!strict
--[=[
	CLDR cardinal plural rules: which form of a word (`one`, `few`, `many`, `other`, …) a number takes in a language.
	Nothing here is specific to units; [MetricUnitFormatUtils] uses it to pick a translated unit name's form.

	@class PluralCategoryUtils
]=]

local require = require(script.Parent.loader).load(script)

local ResolveLocaleUtils = require("ResolveLocaleUtils")

local PluralCategoryUtils = {}

local DEFAULT_LOCALE = "en-us"

--[=[
	A CLDR plural category. A translated name has a key for each category its language uses.

	@type PluralCategory "zero" | "one" | "two" | "few" | "many" | "other"
	@within PluralCategoryUtils
]=]
export type PluralCategory = "zero" | "one" | "two" | "few" | "many" | "other"

--[=[
	The CLDR plural category of a number as written in `locale`, from CLDR's cardinal plural rules for every language
	[MetricUnitTranslator] ships. `amount` is the rounded value shown and `fraction` the decimals written after the
	decimal mark (`"50"` for "1.50"), since English writes "1 meter" but "1.0 meters".

	- `one` only: English, German (`i = 1 and v = 0`); Spanish and Turkish (`n = 1`); Vietnamese (`i = 0 or n = 1`).
	- `one` and `many`: French and Portuguese (`one` for `i = 0..1`), Italian (`one` for `i = 1 and v = 0`); `many`
	  is a whole multiple of a million, as Spanish also has.
	- `one`, `few`, `many`: Russian and Polish, for whole numbers; their fractions are `other`.
	- `zero`, `one`, `two`, `few`, `many`: Arabic.
	- `other` only: Chinese, Japanese, Korean, Thai and Indonesian.

	```lua
	PluralCategoryUtils.getPluralCategory("en-us", 1) -- "one"
	PluralCategoryUtils.getPluralCategory("en-us", 1, "0") -- "other", as in "1.0 meters"
	PluralCategoryUtils.getPluralCategory("fr-fr", 1.5, "5") -- "one"
	PluralCategoryUtils.getPluralCategory("ru-ru", 3) -- "few"
	PluralCategoryUtils.getPluralCategory("ar", 11) -- "many"
	```

	@param locale string?
	@param amount number
	@param fraction string? -- the decimals written, if any
	@return PluralCategory
]=]
function PluralCategoryUtils.getPluralCategory(locale: string?, amount: number, fraction: string?): PluralCategory
	local language = ResolveLocaleUtils.getLanguageSubtag(locale or DEFAULT_LOCALE) or "en"

	local absoluteValue = math.abs(amount)
	local integerPart = math.floor(absoluteValue)
	local decimalsWritten = if fraction then #fraction elseif absoluteValue ~= integerPart then 1 else 0
	local isWholeMillion = decimalsWritten == 0 and integerPart ~= 0 and integerPart % 1_000_000 == 0

	if language == "en" or language == "de" then
		return if integerPart == 1 and decimalsWritten == 0 then "one" else "other"
	elseif language == "es" then
		return if absoluteValue == 1 then "one" elseif isWholeMillion then "many" else "other"
	elseif language == "fr" or language == "pt" then
		return if integerPart == 0 or integerPart == 1 then "one" elseif isWholeMillion then "many" else "other"
	elseif language == "it" then
		return if integerPart == 1 and decimalsWritten == 0 then "one" elseif isWholeMillion then "many" else "other"
	elseif language == "tr" then
		return if absoluteValue == 1 then "one" else "other"
	elseif language == "vi" then
		return if integerPart == 0 or absoluteValue == 1 then "one" else "other"
	elseif language == "ru" or language == "pl" then
		if decimalsWritten ~= 0 then
			return "other"
		end
		local ones, tens = integerPart % 10, integerPart % 100
		if language == "pl" and integerPart == 1 then
			return "one"
		elseif language == "ru" and ones == 1 and tens ~= 11 then
			return "one"
		elseif ones >= 2 and ones <= 4 and (tens < 12 or tens > 14) then
			return "few"
		end
		return "many"
	elseif language == "ar" then
		if absoluteValue == 0 then
			return "zero"
		elseif absoluteValue == 1 then
			return "one"
		elseif absoluteValue == 2 then
			return "two"
		elseif absoluteValue == integerPart then
			local lastTwoDigits = integerPart % 100
			if lastTwoDigits >= 3 and lastTwoDigits <= 10 then
				return "few"
			elseif lastTwoDigits >= 11 then
				return "many"
			end
		end
		return "other"
	end
	return "other"
end

return table.freeze(PluralCategoryUtils)
