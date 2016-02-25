-- @author Narrev

local firstRequired = os.time()

local date = function(optString, unix)
	local stringPassed = false
	
	if not (optString == nil and unix == nil) then
	-- This adds compatibility for Roblox JSON and MarketPlace format, and the different ways this function accepts parameters
		if type(optString) == "number" or optString:match("/Date%((%d+)") or optString:match("%d+\-%d+\-%d+T%d+:%d+:[%d%.]+.+") then
			-- if they didn't pass a non unix time
			unix, optString = optString
		elseif type(optString) == "string" and optString ~= "*t" then
			assert(optString:find("%%[_cxXTrRaAbBdHIjMmpsSuwyY]"), "Invalid string passed to os.date")
			unix, optString = optString:find("^!") and os.time() or unix, optString:find("^!") and optString:sub(2) or optString
			stringPassed = true
		end

		if type(unix) == "string" then -- If it is a unix time, but in a Roblox format
			if unix:match("/Date%((%d+)") then -- This is for a certain JSON compatibility. It works the same even if you don't need it
				unix = unix:match("/Date%((%d+)") / 1000
			elseif unix:match("%d+\-%d+\-%d+T%d+:%d+:[%d%.]+.+") then -- Untested MarketPlaceService compatibility
				-- This part of the script is untested
				local year, month, day, hour, minute, second = unix:match("(%d+)\-(%d+)\-(%d+)T(%d+):(%d+):([%d%.]+).+")
				unix = os.time{year = year, month = month, day = day, hour = hour, minute = minute, second = second}
			end
		end
	else
		optString, stringPassed = "%c", true
	end
	local floor, ceil	= math.floor, math.ceil
	local overflow		= function(tab, seed) for i = 1, #tab do if seed - tab[i] <= 0 then return i, seed end seed = seed - tab[i] end end
	local dayAlign		= unix == 0 and 1 or 0 -- fixes calculation for unix == 0
	local unix		= type(unix) == "number" and unix + dayAlign or tick()
	local days, month, year	= ceil(unix / 86400) + 719527
	local wday		= (days + 6) % 7
	local _4Years		= 400*floor(days / 146097) + 100*floor(days % 146097 / 36524) + 4*floor(days % 146097 % 36524 / 1461)
	      year, days	= overflow({366,365,365,365}, days - 365*_4Years - floor(.25*_4Years - .25) - floor(.0025*_4Years - .0025) + floor(.01*_4Years - .01)) -- [0-1461]
	      year, _4Years	= year + _4Years - 1
	local yDay		= days
	      month, days	= overflow({31,(year%4==0 and(year%25~=0 or year%16==0))and 29 or 28,31,30,31,30,31,31,30,31,30,31}, days)
	local hours		= floor(unix / 3600 % 24)
	local minutes		= floor(unix / 60 % 60)
	local seconds		= floor(unix % 60) - dayAlign
	
	local dayNamesAbbr	= {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"} -- Consider using dayNames[wday + 1]:sub(1,3)
	local dayNames		= {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
	local months		= {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
	local suffixes		= {"st", "nd", "rd", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th", "th", "st"}

	if stringPassed then
		local padded = function(num)
			return string.format("%02d", num)
		end
		return (optString
		:gsub("%%c",  "%%x %%X")
		:gsub("%%_c", "%%_x %%_X")
		:gsub("%%x",  "%%m/%%d/%%y")
		:gsub("%%_x", "%%_m/%%_d/%%y")
		:gsub("%%X",  "%%H:%%M:%%S")
		:gsub("%%_X", "%%_H:%%M:%%S")
		:gsub("%%T",  "%%I:%%M %%p")
		:gsub("%%_T", "%%_I:%%M %%p")
		:gsub("%%r",  "%%I:%%M:%%S %%p")
		:gsub("%%_r", "%%_I:%%M:%%S %%p")
		:gsub("%%R",  "%%H:%%M")		
		:gsub("%%_R", "%%_H:%%M")
		:gsub("%%a", dayNamesAbbr[wday + 1])
		:gsub("%%A", dayNames[wday + 1])
		:gsub("%%b", months[month]:sub(1,3))
		:gsub("%%B", months[month])
		:gsub("%%d", padded(days))
		:gsub("%%_d", days)
		:gsub("%%H", padded(hours))
		:gsub("%%_H", hours)
		:gsub("%%I", padded(hours > 12 and hours - 12 or hours == 0 and 12 or hours))
		:gsub("%%_I", hours > 12 and hours - 12 or hours == 0 and 12 or hours)
		:gsub("%%j", padded(yDay))
		:gsub("%%_j", yDay)
		:gsub("%%M", padded(minutes))
		:gsub("%%_M", minutes)
		:gsub("%%m", padded(month))		
		:gsub("%%_m", month)
		:gsub("%%n","\n")
		:gsub("%%p", hours >= 12 and "pm" or "am")
		:gsub("%%_p", hours >= 12 and "PM" or "AM")
		:gsub("%%s", suffixes[days])
		:gsub("%%S", padded(seconds))
		:gsub("%%_S", seconds)
		:gsub("%%t", "\t")
		:gsub("%%u", wday == 0 and 7 or wday)
		:gsub("%%w", wday)
		:gsub("%%Y", year)
		:gsub("%%y", padded(year % 100))
		:gsub("%%_y", year % 100)
		:gsub("%%%%", "%%")
		)
	end
	return {year = year, month = month, day = days, yday = yDay, wday = wday, hour = hours, min = minutes, sec = seconds}
end

local clock = function() return os.time() - firstRequired end

return setmetatable({date, clock}, {__index = os})
