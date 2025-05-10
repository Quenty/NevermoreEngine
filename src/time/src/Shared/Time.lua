--[=[
	Library handles time based parsing / operations. Untested. Based off of PHP's time system.

	:::note
	This library is out of date, and does not necessarily work. I recommend using os.time()
	:::

	@class Time
]=]

local Time = {}

-- luacheck: push ignore 631
local MONTH_NAMES = {
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December",
}
local MONTH_NAMES_SHORT = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local DAYS_IN_MONTH = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
local DAYS_OF_WEEK = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
local DAYS_OF_WEEK_SHORT = { "Sun", "Mon", "Tues", "Weds", "Thurs", "Fri", "Sat" }
-- luacheck: pop

--[=[
	Returns a Days in months table for the given year
	@param year number
	@return { [number]: number }
]=]
function Time.getDaysMonthTable(year: number): { [number]: number }
	local copy = table.clone(DAYS_IN_MONTH)

	if year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then
		copy[2] = 29
	else
		copy[2] = 28
	end

	return copy
end

function Time.getSecond(currentTime: number): number
	return math.floor(currentTime % 60)
end

function Time.getMinute(currentTime: number): number
	return math.floor(currentTime / 60 % 60)
end

function Time.getHour(currentTime: number): number
	return math.floor(currentTime / 3600 % 24)
end

function Time.getDay(currentTime: number): number
	return math.ceil(currentTime / 60 / 60 / 24 % 365.25)
end

function Time.getYear(currentTime: number): number
	return math.floor(currentTime / 60 / 60 / 24 / 365.25 + 1970)
end

function Time.getYearShort(currentTime: number): number
	return Time.getYear(currentTime) % 100
end

function Time.getYearShortFormatted(currentTime: number): string
	local shortYear = Time.getYearShort(currentTime)
	if shortYear < 10 then
		shortYear = "0" .. shortYear
	end
	return shortYear
end

function Time.getMonth(currentTime: number): number?
	local year = Time.getYear(currentTime)
	local day = Time.getDay(currentTime)

	local daysInMonth = Time.getDaysMonthTable(year)

	for i = 1, #daysInMonth do
		if day > daysInMonth[i] then
			day = day - daysInMonth[i]
		else
			return i
		end
	end

	return nil
end

function Time.getFormattedMonth(currentTime: number): string
	local month = Time.getMonth(currentTime)
	if month < 10 then
		month = "0" .. month
	end

	return month
end

function Time.getDayOfTheMonth(currentTime: number): number?
	local year = Time.getYear(currentTime)
	local day = Time.getDay(currentTime)

	local daysInMonth = Time.getDaysMonthTable(year)

	for i = 1, #daysInMonth do
		if day > daysInMonth[i] then
			day = day - daysInMonth[i]
		else
			return day
		end
	end

	return nil
end

function Time.getFormattedDayOfTheMonth(currentTime: number): string
	local dayOfTheMonth = Time.getDayOfTheMonth(currentTime)

	if dayOfTheMonth < 10 then
		dayOfTheMonth = "0" .. dayOfTheMonth
	end

	return dayOfTheMonth
end

function Time.getMonthName(currentTime: number): string
	local month = Time.getMonth(currentTime)
	if month == nil then
		return "Unknown"
	end

	return MONTH_NAMES[month]
end

function Time.getMonthNameShort(currentTime: number): string
	local month = Time.getMonth(currentTime)
	if month == nil then
		return "???"
	end

	return MONTH_NAMES_SHORT[month]
end

function Time.getJulianDate(currentTime: number)
	local month = Time.getMonth(currentTime)
	local year = Time.getYear(currentTime)
	local day = Time.getDay(currentTime)

	local a = (14 - month) / 12
	local y = year + 4800 - a
	local m = month + 12 * a - 3

	local julianDay = day + ((153 * m + 2) / 5) + 365 * y + (y / 4) - (y / 100) + (y / 400) - 32045

	--[[local julianDay = (day
	+ ((153 * (month + 12 * ((14 - month) / 12 ) - 3) + 2) / 5)
	+ (365 * (year + 4800 - ((14 - month) / 12)))
	+ ((year + 4800 - ((14 - month) / 12)) / 4)
	+ ((year + 4800 - ((14 - month) / 12)) / 100)
	+ ((year + 4800 - ((14 - month) / 12)) / 400)
	- 32045)--]]

	return julianDay
end

function Time.getDayOfTheWeek(currentTime: number): number
	return math.floor(Time.getJulianDate(currentTime)) % 7
end

function Time.getDayOfTheWeekName(currentTime: number): string
	return DAYS_OF_WEEK[Time.getDayOfTheWeek(currentTime)]
end

function Time.getDayOfTheWeekNameShort(currentTime: number): string
	return DAYS_OF_WEEK_SHORT[Time.getDayOfTheWeek(currentTime)]
end

--[=[
	@param number number
	@return string (Like 1st, 2nd)
]=]
function Time.getOrdinalOfNumber(number: number): string
	local tenRemainder = number % 10
	local hundredRemainder = number % 100

	if hundredRemainder >= 10 and hundredRemainder <= 20 then
		return "th"
	end

	if tenRemainder == 1 then
		return "st"
	elseif tenRemainder == 2 then
		return "nd"
	elseif tenRemainder == 3 then
		return "rd"
	else
		return "th"
	end
end

function Time.getDayOfTheMonthOrdinal(currentTime: number): string?
	local dayOfMonth = Time.getDayOfTheMonth(currentTime)
	if dayOfMonth == nil then
		return nil
	end

	return Time.getOrdinalOfNumber(dayOfMonth)
end

function Time.getFormattedSecond(currentTime: number): string
	local currentSecond = Time.getSecond(currentTime)
	if currentSecond < 10 then
		currentSecond = "0" .. currentSecond
	end
	return currentSecond
end

function Time.getFormattedMinute(currentTime: number): string
	local currentMinute = Time.getMinute(currentTime)
	if currentMinute < 10 then
		currentMinute = "0" .. currentMinute
	end
	return currentMinute
end

function Time.getRegularHour(currentTime: number): number
	local hour = Time.getHour(currentTime)
	if hour > 12 then
		hour = hour - 12
	end
	return hour
end

function Time.getHourFormatted(currentTime): string
	local hour = Time.getHour(currentTime)
	if hour < 10 then
		hour = "0" .. hour
	end
	return hour
end

function Time.getRegularHourFormatted(currentTime: number): string
	local hour = Time.getRegularHour(currentTime)
	if hour < 10 then
		hour = "0" .. hour
	end
	return hour
end

function Time.getamOrpm(currentTime: number): "am" | "pm"
	local hour = Time.getHour(currentTime)

	if hour > 12 then
		return "pm"
	else
		return "am"
	end
end

function Time.getAMorPM(currentTime: number): "AM" | "PM"
	local hour = Time.getHour(currentTime)

	if hour > 12 then
		return "PM"
	else
		return "AM"
	end
end

function Time.getMilitaryHour(currentTime: number): string
	local hour = Time.getHour(currentTime)
	if hour < 10 then
		return "0" .. hour
	end
	return hour
end

function Time.isLeapYear(currentTime: number): boolean
	local year = Time.getYear(currentTime)
	if year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then
		return true
	else
		return false
	end
end

function Time.getDaysInMonth(currentTime: number): number
	local month = Time.getMonth(currentTime)
	local year = Time.getYear(currentTime)
	return Time.getDaysMonthTable(year)[month]
end

local ISO_FORMAT_STRINGS = {
	d = Time.getFormattedDayOfTheMonth,
	D = Time.getDayOfTheWeekNameShort,
	j = Time.getDayOfTheMonth,
	l = Time.getDayOfTheWeekName,
	N = Time.getDayOfTheWeek,
	S = Time.getDayOfTheMonthOrdinal,
	W = Time.getDayOfTheWeek,
	Z = Time.getDay,

	-- W

	F = Time.getMonthName,
	m = Time.getFormattedMonth,
	M = Time.getMonthNameShort,
	n = Time.getMonth,
	t = Time.getDaysInMonth,

	L = Time.isLeapYear,
	o = Time.getYear,
	Y = Time.getYear, -- Screw ISO-8610, it confuses me.
	y = Time.getYearShortFormatted,

	a = Time.getamOrpm,
	A = Time.getAMorPM,
	--B -- No one uses it
	g = Time.getRegularHour,
	G = Time.getHour,
	h = Time.getRegularHourFormatted,
	H = Time.getHourFormatted,
	i = Time.getFormattedMinute,
	s = Time.getFormattedSecond,

	X = Time.getJulianDate, -- For testing purposes.

	-- e -- No way to get Time Zones
	-- I -- Daylight saving time should be added later.
	-- O -- No way to get Time Zones
	-- P -- No way to get Time Zones
	-- T -- No way to get Time Zones
	-- Z -- No way to get Time Zones

	-- c -- ISO 8601
	-- r -- No need for formatted dates
	U = time,
}

local matchString: string = "["
do
	for i, _ in ISO_FORMAT_STRINGS do
		matchString ..= i
	end
	matchString ..= "]"
end

function Time.getFormattedTime(format: string, currentTime: number)
	currentTime = currentTime or tick()

	local returnString = format
	local formatsRequired = {}

	for newFormat in string.gmatch(format, matchString) do
		formatsRequired[#formatsRequired + 1] = newFormat
	end

	for _, formatType in formatsRequired do
		returnString = string.gsub(returnString, formatType, string.rep(formatType, 3))
	end

	for _, formatType in formatsRequired do
		local replacement = ISO_FORMAT_STRINGS[formatType](currentTime)
		returnString = string.gsub(returnString, string.rep(formatType, 3), replacement)
	end

	return returnString
end

return Time
