--!strict
--[=[
    Pseudo localizes text. Useful for verifying translation without having
    actual translations available

    @class PseudoLocalize
]=]

local PseudoLocalize = {}

local DEFAULT_PSEUDO_LOCALE_ID = "qlp-pls"

--[=[
    Translates a line into pseudo text while maintaining params
    @param line string -- The line to translate
    @return string -- The translated line
]=]
function PseudoLocalize.pseudoLocalize(line: string): string
	local charMap = PseudoLocalize.PSEUDO_CHARACTER_MAP
	local out = ""
	local isParam = false

	for start, stop in utf8.graphemes(line) do
		local char = string.sub(line, start, stop)
		if char == "{" or char == "[" or char == "<" then
			isParam = true
			out ..= char
		elseif char == "}" or char == "]" or char == ">" then
			isParam = false
			out ..= char
		elseif not isParam and charMap[char] then
			out ..= charMap[char]
		else
			out ..= char
		end
	end

	return out
end

--[=[
    Gets the default pseudo locale string.
    @return string
]=]
function PseudoLocalize.getDefaultPseudoLocaleId(): string
	return DEFAULT_PSEUDO_LOCALE_ID
end

--[=[
    Parses a localization table and adds a pseudo localized locale to the table.

    @param localizationTable LocalizationTable -- LocalizationTable to add to.
    @param preferredLocaleId string? -- Preferred locale to use. Defaults to "qlp-pls"
    @param preferredFromLocale string? -- Preferred from locale. Defaults to "en-us"
    @return string -- The translated line
]=]
function PseudoLocalize.addToLocalizationTable(localizationTable: LocalizationTable, preferredLocaleId: string?, preferredFromLocale: string?)
	local localeId = preferredLocaleId or DEFAULT_PSEUDO_LOCALE_ID
	local fromLocale = preferredFromLocale or "en"

	local entries = localizationTable:GetEntries()
	for _, entry in entries do
		if not entry.Values[localeId] then
			local line = entry.Values[fromLocale]
			if type(line) == "string" then
				entry.Values[localeId] = PseudoLocalize.pseudoLocalize(line)
			else
				warn(string.format("[PseudoLocalize.addToLocalizationTable] - No entry in key %q for locale %q", entry.Key, fromLocale))
			end
		end
	end

	localizationTable:SetEntries(entries)
end

--[=[
    Mapping of English characters to pseudo localized characters.

    @prop PSEUDO_CHARACTER_MAP { [string]: string }
    @within PseudoLocalize
]=]
PseudoLocalize.PSEUDO_CHARACTER_MAP = {
    ["a"] = "á";
    ["b"] = "β";
    ["c"] = "ç";
    ["d"] = "δ";
    ["e"] = "è";
    ["f"] = "ƒ";
    ["g"] = "ϱ";
    ["h"] = "λ";
    ["i"] = "ï";
    ["j"] = "J";
    ["k"] = "ƙ";
    ["l"] = "ℓ";
    ["m"] = "₥";
    ["n"] = "ñ";
    ["o"] = "ô";
    ["p"] = "ƥ";
    ["q"] = "9";
    ["r"] = "ř";
    ["s"] = "ƨ";
    ["t"] = "ƭ";
    ["u"] = "ú";
    ["v"] = "Ʋ";
    ["w"] = "ω";
    ["x"] = "ж";
    ["y"] = "¥";
    ["z"] = "ƺ";
    ["A"] = "Â";
    ["B"] = "ß";
    ["C"] = "Ç";
    ["D"] = "Ð";
    ["E"] = "É";
    ["F"] = "F";
    ["G"] = "G";
    ["H"] = "H";
    ["I"] = "Ì";
    ["J"] = "J";
    ["K"] = "K";
    ["L"] = "£";
    ["M"] = "M";
    ["N"] = "N";
    ["O"] = "Ó";
    ["P"] = "Þ";
    ["Q"] = "Q";
    ["R"] = "R";
    ["S"] = "§";
    ["T"] = "T";
    ["U"] = "Û";
    ["V"] = "V";
    ["W"] = "W";
    ["X"] = "X";
    ["Y"] = "Ý";
    ["Z"] = "Z";
}

return PseudoLocalize