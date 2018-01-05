--- Library handles time based parsing / operations. Untested. Based off of PHP.
-- @module Time

local lib = {}

local MONTH_NAMES        = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
local MONTH_NAMES_SHORT  = {"Jan",     "Feb",      "Mar",   "Apr",   "May", "Jun",  "Jul",  "Aug",    "Sep",       "Oct",     "Nov",      "Dec"}
local DAYS_IN_MONTH      = { 31,        28,         31,      30,      31,    30,     31,     31,       30,          31,       30,         31}
local DAYS_OF_WEEK       = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
local DAYS_OF_WEEK_SHORT = {"Sun",    "Mon",    "Tues",    "Weds",      "Thurs",    "Fri",    "Sat"}

--- Returns a Days in months table for the given year
local function GetDaysMonth(Year)
	local Copy = {}
	for Index, Value in pairs(DAYS_IN_MONTH) do
		Copy[Index] = Value
	end

	if Year % 4 == 0 and (Year % 100 ~= 0 or Year % 400 == 0) then
		Copy[2] = 29
	else
		Copy[2] = 28
	end

	return Copy
end

function lib.GetSecond(CurrentTime)
	return math.floor(CurrentTime % 60)
end

function lib.GetMinute(CurrentTime)
	return math.floor(CurrentTime/60 % 60)
end

function lib.GetHour(CurrentTime)
	return math.floor(CurrentTime/3600 % 24)
end

function lib.GetDay(CurrentTime)
	local CurrentDay = math.ceil(CurrentTime/60/60/24 % 365.25)
	return CurrentDay
end

function lib.GetYear(CurrentTime) 
	local CurrentYear = math.floor(CurrentTime/60/60/24/365.25 + 1970)

	return CurrentYear
end

function lib.GetYearShort(CurrentTime)
	local Year = lib.GetYear(CurrentTime)
	return Year % 100
end

function lib.GetYearShortFormatted(CurrentTime) 
	local ShortYear = lib.GetYearShort(CurrentTime)
	if ShortYear < 10 then
		ShortYear = "0" .. ShortYear
	end
	return ShortYear
end

function lib.GetMonth(CurrentTime)
	local Year = lib.GetYear(CurrentTime)
	local Day = lib.GetDay(CurrentTime)
	local Month

	local DaysInMonth = GetDaysMonth(Year)

	for Index=1, #DaysInMonth do
		if Day > DaysInMonth[Index] then
			Day = Day - DaysInMonth[Index]
		else
			return Index
		end
	end
end

function lib.GetFormattedMonth(CurrentTime)
	local Month = lib.GetMonth(CurrentTime)
	if Month < 10 then
		Month = "0"..Month
	end

	return Month
end

function lib.GetDayOfTheMonth(CurrentTime)
	local Year = lib.GetYear(CurrentTime)
	local Day = lib.GetDay(CurrentTime)
	local DayOfTheMonth

	local DaysInMonth = GetDaysMonth(Year)

	for Index=1, #DaysInMonth do
		if Day > DaysInMonth[Index] then
			Day = Day - DaysInMonth[Index]
		else
			return Day
		end
	end
end

function lib.GetFormattedDayOfTheMonth(CurrentTime)
	local DayOfTheMonth = lib.GetDayOfTheMonth(CurrentTime)

	if DayOfTheMonth < 10 then
		DayOfTheMonth = "0"..DayOfTheMonth
	end

	return DayOfTheMonth
end

function lib.GetMonthName(CurrentTime)
	return MONTH_NAMES[lib.GetMonth(CurrentTime)]
end

function lib.GetMonthNameShort(CurrentTime)
	return MONTH_NAMES_SHORT[lib.GetMonth(CurrentTime)]
end

function lib.GetJulianDate(CurrentTime)
	local Month = lib.GetMonth(CurrentTime)
	local Year = lib.GetYear(CurrentTime)
	local Day = lib.GetDay(CurrentTime)

	local A = (14-Month) / 12
	local Y = Year + 4800 - A
	local M = Month + 12 * A - 3

	local JulianDay = Day + ((153 * M + 2) / 5) + 365 * Y + (Y/4) - (Y/100) + (Y/400) - 32045

	--[[local JulianDay = (Day 
	+ ((153 * (Month + 12 * ((14 - Month) / 12 ) - 3) + 2) / 5)
	+ (365 * (Year + 4800 - ((14 - Month) / 12)))
	+ ((Year + 4800 - ((14 - Month) / 12)) / 4)
	+ ((Year + 4800 - ((14 - Month) / 12)) / 100)
	+ ((Year + 4800 - ((14 - Month) / 12)) / 400)
	- 32045)--]]

	return JulianDay
end

function lib.GetDayOfTheWeek(CurrentTime)

	local JulianTime = lib.GetJulianDate(CurrentTime)

	return math.floor(JulianTime) % 7
end

function lib.GetDayOfTheWeekName(CurrentTime)
	local DayOfTheWeek = lib.GetDayOfTheWeek(CurrentTime)
	local Name = DAYS_OF_WEEK[DayOfTheWeek]

	return Name
end

function lib.GetDayOfTheWeekNameShort(CurrentTime) 
	local DayOfTheWeek = lib.GetDayOfTheWeek(CurrentTime)
	local Name = DAYS_OF_WEEK_SHORT[DayOfTheWeek] 

	return Name
end

---
-- @return st, nd (Like 1st, 2nd)
function lib.GetOrdinalOfNumber(Number) 
	local TenRemainder = Number % 10
	local HundredRemainder = Number % 100

	if HundredRemainder >= 10 and HundredRemainder <= 20 then
		return "th"
	end

	if TenRemainder == 1 then
		return "st"
	elseif TenRemainder == 2 then
		return "nd"
	elseif TenRemainder == 3 then
		return "rd"
	else
		return "th"
	end
end

function lib.GetDayOfTheMonthOrdinal(CurrentTime)
	local DayOfTheMonth = lib.GetDayOfTheMonth(CurrentTime)

	return lib.GetOrdinalOfNumber(DayOfTheMonth)
end

function lib.GetFormattedSecond(CurrentTime)
	local CurrentSecond = lib.GetSecond(CurrentTime)
	if CurrentSecond < 10 then
		CurrentSecond = "0"..CurrentSecond
	end
	return CurrentSecond
end

function lib.GetFormattedMinute(CurrentTime)
	local CurrentMinute = lib.GetMinute(CurrentTime)

	if CurrentMinute < 10 then
		CurrentMinute = "0".. CurrentMinute
	end

	return CurrentMinute
end

function lib.GetRegularHour(CurrentTime)
	local CurrentHour = lib.GetHour(CurrentTime)

	if CurrentHour > 12 then
		CurrentHour = CurrentHour - 12
	end

	return CurrentHour
end

function lib.GetHourFormatted(CurrentTime)
	local CurrentHour = lib.GetHour(CurrentTime)

	if CurrentHour < 10 then
		CurrentHour = "0"..CurrentHour
	end

	return CurrentHour
end

function lib.GetRegularHourFormatted(CurrentTime)
	local CurrentHour = lib.GetRegularHour(CurrentTime)

	if CurrentHour < 10 then
		CurrentHour = "0"..CurrentHour
	end

	return CurrentHour
end

function lib.GetamOrpm(CurrentTime)
	local CurrentHour = lib.GetHour(CurrentTime)

	if CurrentHour > 12 then
		return "pm"
	else
		return "am"
	end
end

function lib.GetAMorPM(CurrentTime)
	local CurrentHour = lib.GetHour(CurrentTime)

	if CurrentHour > 12 then
		return "PM"
	else
		return "AM"
	end
end

function lib.GetMilitaryHour(CurrentTime)
	local CurrentHour = lib.GetHour(CurrentTime)

	if CurrentHour < 10 then
		CurrentHour = "0"..CurrentHour
	end
end

function lib.LeapYear(CurrentTime)
	local Year = lib.GetYear(CurrentTime)

	if Year % 4 == 0 and (Year % 100 ~= 0 or Year % 400 == 0) then
		return 1
	else
		return 0
	end
end

function lib.GetDaysInMonth(CurrentTime)
	local Month = lib.GetMonth(CurrentTime)
	local Year = lib.GetYear(CurrentTime)

	return GetDaysMonth(Year)[Month]
end

local ISO_FORMAT_STRINGS = {
	d = lib.GetFormattedDayOfTheMonth;
	D = lib.GetDayOfTheWeekNameShort;
	j = lib.GetDayOfTheMonth;
	l = lib.GetDayOfTheWeekName;
	N = lib.GetDayOfTheWeek;
	S = lib.GetDayOfTheMonthOrdinal;
	W = lib.GetDayOfTheWeek;
	Z = lib.GetDay;

	-- W 

	F = lib.GetMonthName;
	m = lib.GetFormattedMonth;
	M = lib.GetMonthNameShort;
	n = lib.GetMonth;
	t = lib.GetDaysInMonth;

	L = lib.LeapYear;
	o = lib.GetYear;
	Y = lib.GetYear; -- Screw ISO-8610, it confuses me.
	y = lib.GetYearShortFormatted;

	a = lib.GetamOrpm;
	A = lib.GetAMorPM;
	--B -- No one uses it
	g = lib.GetRegularHour;
	G = lib.GetHour;
	h = lib.GetRegularHourFormatted;
	H = lib.GetHourFormatted;
	i = lib.GetFormattedMinute;
	s = lib.GetFormattedSecond;

	X = lib.GetJulianDate; -- For testing purposes.

	-- e -- No way to get Time Zones
	-- I -- Daylight saving time should be added later.
	-- O -- No way to get Time Zones
	-- P -- No way to get Time Zones
	-- T -- No way to get Time Zones
	-- Z -- No way to get Time Zones

	-- c -- ISO 8601
	-- r -- No need for formatted dates
	U = time;
}

local MatchString = "[" do
	for Index, Value in pairs(ISO_FORMAT_STRINGS) do
		MatchString = MatchString .. Index
	end
	MatchString = MatchString .. "]"
end

function lib.GetFormattedTime(Format, CurrentTime)
	CurrentTime = CurrentTime or tick()

	local ReturnString = Format
	local FormatsRequired = {}

	for NewFormat in string.gmatch(Format, MatchString) do
		FormatsRequired[#FormatsRequired+1] = NewFormat
	end

	for _, FormatType in pairs(FormatsRequired) do
		ReturnString = ReturnString:gsub(FormatType, FormatType:rep(3))
	end

	for _, FormatType in pairs(FormatsRequired) do
		local Replacement = ISO_FORMAT_STRINGS[FormatType](CurrentTime)
		ReturnString = ReturnString:gsub(FormatType:rep(3), Replacement)
	end

	return ReturnString
end

return lib