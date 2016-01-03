-- to use: local os = require(this_script)
-- @author Narrev

--[[
	This adds os.date back to Roblox! It functions just like Lua's built-in os.date, but with a few additions.
	Note: Padding can be toggled by inserting a '_' like so: os.date("%_x", os.time())
	Note: tick() is the default unix time used for os.date()

	os.date("*t") returns a table with the following indices:
	
	hour	14
	min	36
	wday	1
	year	2003
	yday	124
	month	5
	sec	33
	day	4
	
	String reference:
	%a	abbreviated weekday name (e.g., Wed)
	%A	full weekday name (e.g., Wednesday)
	%b	abbreviated month name (e.g., Sep)
	%B	full month name (e.g., September)
	%c	date and time (e.g., 09/16/98 23:48:10)
	%d	day of the month (16) [01-31]
	%H	hour, using a 24-hour clock (23) [00-23]
	%I	hour, using a 12-hour clock (11) [01-12]
	%j	day of year [01-365]
	%M	minute (48) [00-59]
	%m	month (09) [01-12]
	%n	New-line character ('\n')
	%p	either "am" or "pm" ('_' makes it uppercase)
	%r	12-hour clock time *	02:55:02 pm
	%R	24-hour HH:MM time, equivalent to %H:%M	14:55
	%s	day suffix
	%S	second (10) [00-61]
	%t	Horizontal-tab character ('\t')
	%T	Basically %r but without seconds (HH:MM AM), equivalent to %I:%M %p	2:55 pm
	%u	ISO 8601 weekday as number with Monday as 1 (1-7)	4
	%w	weekday (3) [0-6 = Sunday-Saturday]
	%x	date (e.g., 09/16/98)
	%X	time (e.g., 23:48:10)
	%Y	full year (1998)
	%y	two-digit year (98) [00-99]
	%%	the character `%´
	
	os.clock() returns how long the server has been active, or more realistically, how long since when you required this module
	os.UTCToTick returns your time in seconds given @param UTC time in seconds
--]]

-- Abbreviated tables have been left in for now. Could be replaced with dayNames[wday + 1]:sub(1,3)

local firstRequired = os.time()

return {
	date = function(optString, unix)
		local stringPassed = false

		if not (optString == nil and unix == nil) then
			if type(optString) == "number" or optString:match("/Date%((%d+)") or optString:match("%d+\-%d+\-%d+T%d+:%d+:[%d%.]+.+") then
				-- if they didn't pass a non unix time
				unix, optString = optString
			elseif type(optString) == "string" then
				assert(optString:find("*t") or optString:find("%%"), "Invalid string passed to os.date")
				unix, optString = optString:find("^!") and os.time() or unix, optString:find("^!") and optString:sub(2) or optString
				stringPassed = true
			end

			if type(unix) == "string" then
				if unix:match("/Date%((%d+)") then -- This is for a certain JSON compatibility. It works the same even if you don't need it
					unix = unix:match("/Date%((%d+)") / 1000
				elseif unix:match("%d+\-%d+\-%d+T%d+:%d+:[%d%.]+.+") then -- Untested MarketPlaceService compatibility
					-- This part of the script is untested
					local year, month, day, hour, minute, second = unix:match("(%d+)\-(%d+)\-(%d+)T(%d+):(%d+):([%d%.]+).+")
					unix = os.time{year = year, month = month, day = day, hour = hour, minute = minute, second = second}
				end
			end
		end
		local dayAlign		= unix == 0 and 1 or 0 -- fixes calculation for unix == 0
		local unix		= type(unix) == "number" and unix + dayAlign or tick()
		local dayCount		= function(yr) return (yr % 4 == 0 and (yr % 100 ~= 0 or yr % 400 == 0)) and 366 or 365 end
		local year		= 1970
		local days		= math.ceil(unix / 86400)
		local wday		= math.floor((days + 3) % 7) -- Jan 1, 1970 was a thursday, so we add 3
		local dayNames		= {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
		local dayNamesAbbr	= {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}
		local monthsAbbr	= {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
		local months, month	= {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
		local suffixes		= {"st", "nd", "rd", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th", "th", "st"}
	
		local hours		= math.floor(unix / 3600 % 24)
		local minutes		= math.floor(unix / 60 % 60)
		local seconds		= math.floor(unix % 60) - dayAlign
		
		 -- Calculate year and days into that year
		while days > dayCount(year) do days = days - dayCount(year) year = year + 1 end
		
		local yDay		= days
	
		 -- Subtract amount of days from each month until we find what month we are in and what day in that month
		for monthIndex, daysInMonth in ipairs{31,(dayCount(year) - 337),31,30,31,30,31,31,30,31,30,31} do
			if days - daysInMonth <= 0 then
				month = monthIndex
				break
			end
			days = days - daysInMonth
		end
		-- With the table module, the following can be used instead of the above for loop
		-- month, days = table.overflow({31,(dayCount(year) - 337),31,30,31,30,31,31,30,31,30,31}, days)
		local padded = function(num)
			return string.format("%02d", num)
		end
		
		if stringPassed then
			-- We don't want second argument of gsub
			return (
			optString
			:gsub("%%c", "%%x %%X")
			:gsub("%%_c", "%%_x %%_X")
			:gsub("%%x", "%%m/%%d/%%y")
			:gsub("%%_x", "%%_m/%%_d/%%y")
			:gsub("%%X", "%%H:%%M:%%S")
			:gsub("%%_X", "%%_H:%%M:%%S")
			:gsub("%%T", "%%I:%%M %%p")
			:gsub("%%_T", "%%_I:%%M %%p")
			:gsub("%%r", "%%I:%%M:%%S %%p")
			:gsub("%%_r", "%%_I:%%M:%%S %%p")
			:gsub("%%R", "%%H:%%M")		
			:gsub("%%_R", "%%_H:%%M")
			:gsub("%%a", dayNamesAbbr[wday + 1])
			:gsub("%%A", dayNames[wday + 1])
			:gsub("%%b", monthsAbbr[month])
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
	end;
	UTCToTick = function(time)
		-- UTC time in seconds to your time in seconds
		-- This is for scheduling Roblox events across timezones
		return time + math.ceil(tick()) - os.time()
	end;
	time = function(...) return os.time(...) end;
	difftime = function(...) return os.difftime(...) end;
	clock = function(...) return os.difftime(os.time(), firstRequired) end;
}
