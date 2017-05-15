-- @author Validark

-- Necessary string tables
local dayNames = {[0] = "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
local months = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}

-- Localize functions
local time = os.time
local floor, sub, find, gsub, format = math.floor, string.sub, string.find, string.gsub, string.format
local type, tick, tonumber = type, tick, tonumber

local function date(formatString, unix)
	--- Allows you to use os.date in RobloxLua!
	--		date ([format [, time]])
	-- This doesn't include the explanations for the math. If you want to see how the numbers work, see the following:
	-- http://howardhinnant.github.io/date_algorithms.html#civil_from_days
	--
	-- @param string formatString
	--		If present, function date returns a string formatted by the tags in formatString.
	--		If formatString starts with "!", date is formatted in UTC.
	--		If formatString is "*t", date returns a table
	--		Placing "_" in the middle of a tag (e.g. "%_d" "%_I") removes padding
	--		String Reference: https://github.com/Narrev/NevermoreEngine/blob/patch-5/Modules/Utility/readme.md
	--		@default "%c"
	--
	-- @param number unix
	--		If present, unix is the time to be formatted. Otherwise, date formats the current time.
	--		The amount of seconds since 1970 (negative numbers are occasionally supported)
	--		@default tick()

	-- @returns a string or a table containing date and time, formatted according to the given string format. If called without arguments, returns the equivalent of date("%c").

	-- Find whether formatString was used
	if formatString then
		if type(formatString) == "number" then -- If they didn't pass a formatString, and only passed unix through
			if type(unix) == "string" then error("Invalid parameters passed to os.date. Your parameters might be in the wrong order") end
			unix, formatString = formatString, "%c"
		elseif type(formatString) == "string" then
			if not find(formatString, "*t") and not find(formatString, "%%[_cxXTrRaAbBdHIjMmpsSuwyY]") then
				warn("[os.date] \"" .. formatString .. "\" has nothing to format")
			end
			local UTC
			formatString, UTC = gsub(formatString, "^!", "") -- If formatString begins in '!', use os.time()
			if UTC == 1 and unix then warn("Cannot determine time to format for os.date: Use either an \"!\" at the beginning of the string OR pass a time parameter") end
			unix = unix or UTC == 1 and time()
		end
	else -- If they did not pass a formatting string
		formatString = "%c"
	end

	-- Set unix
	unix = tonumber(unix) or tick()

	-- Get hours, minutes, and seconds
	local hours, minutes, seconds = floor(unix / 3600 % 24), floor(unix / 60 % 60), floor(unix % 60)

	-- Get days, month and year
	local days = floor(unix / 86400) + 719468
	local wday = (days + 3) % 7 -- Day of week with Sunday @0 [0, 6]
	local year = floor((days >= 0 and days or days - 146096) / 146097) -- 400 Year bracket
	days = (days - year * 146097) -- Days into 400 year bracket [0, 146096]
	local years = floor((days - floor(days/1460) + floor(days/36524) - floor(days/146096))/365)	-- Years into 400 Year bracket[0, 399]
	days = days - (365*years + floor(years/4) - floor(years/100)) -- Days into year with March 1st @0 [0, 365]
	local month = floor((5*days + 2)/153) -- Month with March @0 [0, 11]
	local yday = days
	days = days - floor((153*month + 2)/5) + 1 -- Days into month [1, 31]
	month = month + (month < 10 and 3 or -9) -- Actual month [1, 12]
	year = years + year*400 + (month < 3 and 1 or 0) -- Actual Year


	if formatString == "*t" then -- Return a table if "*t" was used
		return {year = year, month = month, day = days, yday = yday, wday = wday, hour = hours, min = minutes, sec = seconds}
	end

	-- Return formatted string
	return (gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(gsub(formatString,
		"%%c",  "%%x %%X"),
		"%%_c", "%%_x %%_X"),
		"%%x",  "%%m/%%d/%%y"),
		"%%_x", "%%_m/%%_d/%%y"),
		"%%X",  "%%H:%%M:%%S"),
		"%%_X", "%%_H:%%M:%%S"),
		"%%T",  "%%I:%%M %%p"),
		"%%_T", "%%_I:%%M %%p"),
		"%%r",  "%%I:%%M:%%S %%p"),
		"%%_r", "%%_I:%%M:%%S %%p"),
		"%%R",  "%%H:%%M"),
		"%%_R", "%%_H:%%M"),
		"%%a", sub(dayNames[wday], 1, 3)),
		"%%A", dayNames[wday]),
		"%%b", sub(months[month], 1, 3)),
		"%%B", months[month]),
		"%%d", format("%02d", days)),
		"%%_d", days),
		"%%H", format("%02d", hours)),
		"%%_H", hours),
		"%%I", format("%02d", hours > 12 and hours - 12 or hours == 0 and 12 or hours)),
		"%%_I", hours > 12 and hours - 12 or hours == 0 and 12 or hours),
		"%%j", format("%02d", yday)),
		"%%_j", yday),
		"%%M", format("%02d", minutes)),
		"%%_M", minutes),
		"%%m", format("%02d", month)),
		"%%_m", month),
		"%%n", "\n"),
		"%%p", hours >= 12 and "pm" or "am"),
		"%%_p", hours >= 12 and "PM" or "AM"),
		"%%s", (days < 21 and days > 3 or days > 23 and days < 31) and "th" or ({"st", "nd", "rd"})[days % 10]),
		"%%S", format("%02d", seconds)),
		"%%_S", seconds),
		"%%t", "\t"),
		"%%u", wday == 0 and 7 or wday),
		"%%w", wday),
		"%%Y", year),
		"%%y", format("%02d", year % 100)),
		"%%_y", year % 100),
		"%%%%", "%%")
	)
end

local function clock()
	return workspace.DistributedGameTime
end

function isLeapYear(year)
	return year % 4 == 0 and (year % 25 ~= 0 or year % 16 == 0)
end

local monthLengths = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}

local function monthLength(month, year)
	return month == 2 and isLeapYear(year) and 29 or monthLengths[month]
end

local os = {
	date = date;
	clock = clock;
	__index = os;
	isLeapYear = isLeapYear;
	monthLength = monthLength;
}

return setmetatable(os, os)
