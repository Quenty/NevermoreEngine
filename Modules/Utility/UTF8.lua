--- UTF8 utility functions
-- @module UTF8

local lib = {}

function lib.upper(str)
	local UPPER_MAP = lib.UPPER_MAP
	str = str:upper()
	local newStr = ""
	for start, stop in utf8.graphemes(str) do
		local chr = str:sub(start, stop)
		if UPPER_MAP[chr] then
			chr = UPPER_MAP[chr]
		end
		newStr = newStr .. chr
	end
	return newStr
end

function lib.lower(str)
	local LOWER_MAP = lib.LOWER_MAP
	str = str:lower()
	local newStr = ""
	for start, stop in utf8.graphemes(str) do
		local chr = str:sub(start, stop)
		if LOWER_MAP[chr] then
			chr = LOWER_MAP[chr]
		end
		newStr = newStr .. chr
	end
	return newStr
end

lib.UPPER_MAP = {
	['à'] = 'À',
	['á'] = 'Á',
	['â'] = 'Â',
	['ã'] = 'Ã',
	['ä'] = 'Ä',
	['å'] = 'Å',
	['æ'] = 'Æ',
	['ç'] = 'Ç',
	['è'] = 'È',
	['é'] = 'É',
	['ê'] = 'Ê',
	['ë'] = 'Ë',
	['ì'] = 'Ì',
	['í'] = 'Í',
	['î'] = 'Î',
	['ï'] = 'Ï',
	['ð'] = 'Ð',
	['ñ'] = 'Ñ',
	['ò'] = 'Ò',
	['ó'] = 'Ó',
	['ô'] = 'Ô',
	['õ'] = 'Õ',
	['ö'] = 'Ö',
	['ø'] = 'Ø',
	['ù'] = 'Ù',
	['ú'] = 'Ú',
	['û'] = 'Û',
	['ü'] = 'Ü',
	['ý'] = 'Ý',
	['þ'] = 'Þ',
	['ā'] = 'Ā',
	['ă'] = 'Ă',
	['ą'] = 'Ą',
	['ć'] = 'Ć',
	['ĉ'] = 'Ĉ',
	['ċ'] = 'Ċ',
	['č'] = 'Č',
	['ď'] = 'Ď',
	['đ'] = 'Đ',
	['ē'] = 'Ē',
	['ĕ'] = 'Ĕ',
	['ė'] = 'Ė',
	['ę'] = 'Ę',
	['ě'] = 'Ě',
	['ĝ'] = 'Ĝ',
	['ğ'] = 'Ğ',
	['ġ'] = 'Ġ',
	['ģ'] = 'Ģ',
	['ĥ'] = 'Ĥ',
	['ħ'] = 'Ħ',
	['ĩ'] = 'Ĩ',
	['ī'] = 'Ī',
	['ĭ'] = 'Ĭ',
	['į'] = 'Į',
	['ı'] = 'İ',
	['ĳ'] = 'Ĳ',
	['ĵ'] = 'Ĵ',
	['ķ'] = 'Ķ',
	['ĺ'] = 'Ĺ',
	['ļ'] = 'Ļ',
	['ľ'] = 'Ľ',
	['ŀ'] = 'Ŀ',
	['ł'] = 'Ł',
	['ń'] = 'Ń',
	['ņ'] = 'Ņ',
	['ň'] = 'Ň',
	['ŋ'] = 'Ŋ',
	['ō'] = 'Ō',
	['ŏ'] = 'Ŏ',
	['ő'] = 'Ő',
	['œ'] = 'Œ',
	['ŕ'] = 'Ŕ',
	['ŗ'] = 'Ŗ',
	['ř'] = 'Ř',
	['ś'] = 'Ś',
	['ŝ'] = 'Ŝ',
	['ş'] = 'Ş',
	['š'] = 'Š',
	['ţ'] = 'Ţ',
	['ť'] = 'Ť',
	['ŧ'] = 'Ŧ',
	['ũ'] = 'Ũ',
	['ū'] = 'Ū',
	['ŭ'] = 'Ŭ',
	['ů'] = 'Ů',
	['ű'] = 'Ű',
	['ų'] = 'Ų',
	['ŵ'] = 'Ŵ',
	['ŷ'] = 'Ŷ',
	['ÿ'] = 'Ÿ',
	['ź'] = 'Ź',
	['ż'] = 'Ż',
	['ž'] = 'Ž',
	['ſ'] = 'ſ',
	['ƀ'] = 'Ɓ',
	['ƃ'] = 'Ƃ',
	['ƅ'] = 'Ƅ',
	['ƈ'] = 'Ƈ',
	['ƌ'] = 'Ƌ',
	['ƒ'] = 'Ƒ',
	['ƙ'] = 'Ƙ',
	['ƣ'] = 'Ƣ',
	['ơ'] = 'Ơ',
}

lib.LOWER_MAP = {}
for key, val in pairs(lib.UPPER_MAP) do
	lib.LOWER_MAP[val] = key
end

return lib