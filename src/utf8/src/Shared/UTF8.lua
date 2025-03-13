--!strict
--[=[
	UTF8 utility functions
	@class UTF8
]=]

local UTF8: {
	UPPER_MAP: { [string]: string },
	LOWER_MAP: { [string]: string },
	upper: (str: string) -> string,
	lower: (str: string) -> string,
} =
	{} :: any

--[=[
	UTF8 uppercase
	@param str string
	@return string
]=]
function UTF8.upper(str: string): string
	local UPPER_MAP = UTF8.UPPER_MAP
	str = string.upper(str)
	local newStr = ""
	for start, stop in utf8.graphemes(str) do
		local chr = string.sub(str, start, stop)
		if UPPER_MAP[chr] then
			chr = UPPER_MAP[chr]
		end
		newStr ..= chr
	end
	return newStr
end

--[=[
	UTF8 lowercase
	@param str string
	@return string
]=]
function UTF8.lower(str: string): string
	local LOWER_MAP = UTF8.LOWER_MAP
	str = string.lower(str)
	local newStr = ""
	for start, stop in utf8.graphemes(str) do
		local chr: string = string.sub(str, start, stop)
		if LOWER_MAP[chr] then
			chr = LOWER_MAP[chr]
		end
		newStr ..= chr
	end
	return newStr
end

--[=[
	UTF8 lower to uppercase map
	@prop UPPER_MAP { [string]: string }
	@within UTF8
]=]
local UPPER_MAP: { [string]: string } = {
	["à"] = "À",
	["á"] = "Á",
	["â"] = "Â",
	["ã"] = "Ã",
	["ä"] = "Ä",
	["å"] = "Å",
	["æ"] = "Æ",
	["ç"] = "Ç",
	["è"] = "È",
	["é"] = "É",
	["ê"] = "Ê",
	["ë"] = "Ë",
	["ì"] = "Ì",
	["í"] = "Í",
	["î"] = "Î",
	["ï"] = "Ï",
	["ð"] = "Ð",
	["ñ"] = "Ñ",
	["ò"] = "Ò",
	["ó"] = "Ó",
	["ô"] = "Ô",
	["õ"] = "Õ",
	["ö"] = "Ö",
	["ø"] = "Ø",
	["ù"] = "Ù",
	["ú"] = "Ú",
	["û"] = "Û",
	["ü"] = "Ü",
	["ý"] = "Ý",
	["þ"] = "Þ",
	["ā"] = "Ā",
	["ă"] = "Ă",
	["ą"] = "Ą",
	["ć"] = "Ć",
	["ĉ"] = "Ĉ",
	["ċ"] = "Ċ",
	["č"] = "Č",
	["ď"] = "Ď",
	["đ"] = "Đ",
	["ē"] = "Ē",
	["ĕ"] = "Ĕ",
	["ė"] = "Ė",
	["ę"] = "Ę",
	["ě"] = "Ě",
	["ĝ"] = "Ĝ",
	["ğ"] = "Ğ",
	["ġ"] = "Ġ",
	["ģ"] = "Ģ",
	["ĥ"] = "Ĥ",
	["ħ"] = "Ħ",
	["ĩ"] = "Ĩ",
	["ī"] = "Ī",
	["ĭ"] = "Ĭ",
	["į"] = "Į",
	["ı"] = "İ",
	["ĳ"] = "Ĳ",
	["ĵ"] = "Ĵ",
	["ķ"] = "Ķ",
	["ĺ"] = "Ĺ",
	["ļ"] = "Ļ",
	["ľ"] = "Ľ",
	["ŀ"] = "Ŀ",
	["ł"] = "Ł",
	["ń"] = "Ń",
	["ņ"] = "Ņ",
	["ň"] = "Ň",
	["ŋ"] = "Ŋ",
	["ō"] = "Ō",
	["ŏ"] = "Ŏ",
	["ő"] = "Ő",
	["œ"] = "Œ",
	["ŕ"] = "Ŕ",
	["ŗ"] = "Ŗ",
	["ř"] = "Ř",
	["ś"] = "Ś",
	["ŝ"] = "Ŝ",
	["ş"] = "Ş",
	["š"] = "Š",
	["ţ"] = "Ţ",
	["ť"] = "Ť",
	["ŧ"] = "Ŧ",
	["ũ"] = "Ũ",
	["ū"] = "Ū",
	["ŭ"] = "Ŭ",
	["ů"] = "Ů",
	["ű"] = "Ű",
	["ų"] = "Ų",
	["ŵ"] = "Ŵ",
	["ŷ"] = "Ŷ",
	["ÿ"] = "Ÿ",
	["ź"] = "Ź",
	["ż"] = "Ż",
	["ž"] = "Ž",
	["ſ"] = "ſ",
	["ƀ"] = "Ɓ",
	["ƃ"] = "Ƃ",
	["ƅ"] = "Ƅ",
	["ƈ"] = "Ƈ",
	["ƌ"] = "Ƌ",
	["ƒ"] = "Ƒ",
	["ƙ"] = "Ƙ",
	["ƣ"] = "Ƣ",
	["ơ"] = "Ơ",
}

--[=[
	UTF8 uppercase to lowercase map
	@prop LOWER_MAP { [string]: string }
	@within UTF8
]=]
local LOWER_MAP: { [string]: string } = {}
for key, val in UPPER_MAP do
	LOWER_MAP[val] = key
end

UTF8.UPPER_MAP = table.freeze(UPPER_MAP)
UTF8.LOWER_MAP = table.freeze(LOWER_MAP)

return UTF8
