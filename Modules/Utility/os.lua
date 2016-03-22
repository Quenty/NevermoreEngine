-- @author Narrev

local function date(formatString, unix)
	--- Allows you to use os.date in RobloxLua!
	--		date ([format [, time]])
	-- 
	-- @param string formatString
	--		If present, function date returns a string formatted by the tags in formatString. 
	--		If formatString starts with "!", date is formatted in UTC.
	--		If formatString is "*t", date returns a table
	--		@default "%c"
	--
	-- @param number unix
	--		If present, unix is the time to be formatted. Otherwise, date formats the current time.
	--		The amount of seconds since 1970 (negative numbers aren't supported, usually)
	--		@default tick()

	-- @returns a string or a table containing date and time, formatted according to the given string format. If called without arguments, returns the equivalent of date("%c").

	-- Localize functions
	local ceil, floor, sub, find, gsub, format = math.ceil, math.floor, string.sub, string.find, string.gsub, string.format

	-- Helper functions
	local function overflow(array, seed)
		--- Subtracts the integer values in an array from a seed until the seed cannot be subtracted from any further
		-- @param array array A table filled with integers to be subtracted from seed
		-- @param integer seed A seed that is subtracted by the values in array until it would become negative from subtraction
		-- @returns index at which the iterated value is greater than the remaining seed and what is left of the seed (before subtracting final value)

		for i = 1, #array do
			if seed - array[i] <= 0 then
				return i, seed
			end
			seed = seed - array[i]
		end
	end

	local function padded(number)
		--- Gives a number padding
		-- @param number The number to give padding
		-- @returns number as a string with a 0 in front if less than 10 
		return format("%02d", number)
	end

	-- Find whether formatString was used
	if formatString then
		if type(formatString) == "number" then -- If they didn't pass a formatString, and only passed unix through
			assert(type(unix) ~= "string", "Invalid parameters passed to os.date. Your parameters might be in the wrong order")
			unix, formatString = formatString, "%c"

		elseif type(formatString) == "string" then
			assert(find(formatString, "*t") or find(formatString, "%%[_cxXTrRaAbBdHIjMmpsSuwyY]"), "Invalid string passed to os.date")
			local UTC
			formatString, UTC = gsub(formatString, "^!", "") -- If formatString begins in '!', use os.time()
			assert(UTC == 0 or not unix, "Cannot determine time to format for os.date. Use either an \"!\" at the beginning of the string or pass a time parameter")
			unix = UTC == 1 and os.time() or unix
		end
	else -- If they did not pass a formatting string
		formatString = "%c"
	end

	-- Declare Variables
	local unix = type(unix) == "number" and unix or tick()

	-- Get hours, minutes, and seconds	
	local hours, minutes, seconds = floor(unix / 3600 % 24), floor(unix / 60 % 60), floor(unix % 60)

	-- Get years, months, and days
	local days, month, year	= ceil((unix + 1) / 86400) + 719527
	local wday		= (days + 6) % 7
	local _4Years		= 400*floor(days / 146097) + 100*floor(days % 146097 / 36524) + 4*floor(days % 146097 % 36524 / 1461) - 1
	      year, days	= overflow({366,365,365,365}, days - 365*(_4Years + 1) - floor(.25*_4Years) - floor(.0025*_4Years) + floor(.01*_4Years)) -- [0-1461]
	      year, _4Years	= year + _4Years -- _4Years is set to nil
	local yDay		= days
	      month, days	= overflow({31,(year%4==0 and(year%25~=0 or year%16==0))and 29 or 28,31,30,31,30,31,31,30,31,30,31}, days)

	if formatString == "*t" then -- Return a table if "*t" was used
		return {year = year, month = month, day = days, yday = yDay, wday = wday, hour = hours, min = minutes, sec = seconds}
	end
	
	-- Necessary string tables
	local dayNames		= {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
	local months		= {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
	local suffixes		= {"st", "nd", "rd", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th", "th", "st"}

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
		"%%a", sub(dayNames[wday + 1], 1, 3)),
		"%%A", dayNames[wday + 1]),
		"%%b", sub(months[month], 1, 3)),
		"%%B", months[month]),
		"%%d", padded(days)),
		"%%_d", days),
		"%%H", padded(hours)),
		"%%_H", hours),
		"%%I", padded(hours > 12 and hours - 12 or hours == 0 and 12 or hours)),
		"%%_I", hours > 12 and hours - 12 or hours == 0 and 12 or hours),
		"%%j", padded(yDay)),
		"%%_j", yDay),
		"%%M", padded(minutes)),
		"%%_M", minutes),
		"%%m", padded(month)),
		"%%_m", month),
		"%%n", "\n"),
		"%%p", hours >= 12 and "pm" or "am"),
		"%%_p", hours >= 12 and "PM" or "AM"),
		"%%s", suffixes[days]),
		"%%S", padded(seconds)),
		"%%_S", seconds),
		"%%t", "\t"),
		"%%u", wday == 0 and 7 or wday),
		"%%w", wday),
		"%%Y", year),
		"%%y", padded(year % 100)),
		"%%_y", year % 100),
		"%%%%", "%%")
	)	
end

local function clock()
	local timeYielded, timeServerHasBeenRunning = wait()
	return timeServerHasBeenRunning
end

return setmetatable({date = date, clock = clock}, {__index = os})
