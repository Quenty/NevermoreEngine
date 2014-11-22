-- qTime.lua
-- Library handles time based parsing / operations. Untested. Based off of PHP.

-- @author Quenty
-- Last modified February 1st, 2014

local lib = {}

--- STATIC DATA ---
local MonthNames         = {"January"; "February"; "March"; "April"; "May"; "June"; "July"; "August"; "September"; "October"; "November"; "December";}
local MonthNamesShort    = {"Jan";     "Feb";      "Mar";   "Apr";   "May"; "Jun";  "Jul";  "Aug";    "Sep";       "Oct";     "Nov";      "Dec";}
local DaysInMonth        = { 31;        28;         31;      30;      31;    30;     31;     31;       30;          31; 30; 31} -- Before reading this table, call FixLeapYear(Year)
local DaysOfTheWeek      = {"Sunday"; "Monday"; "Tuesday"; "Wednesday"; "Thursday"; "Friday"; "Saturday";}
local DaysOfTheWeekShort = {"Sun";    "Mon";    "Tues";    "Weds";      "Thurs";    "Fri";    "Sat";}

-- UTILITY --

local function FixLeapYear(Year)
	--- Fixes The DaysInMonth table, given a year. 

	if Year % 4 == 0 then
		DaysInMonth[2] = 29;
	else
		DaysInMonth[2] = 28;
	end
end

--- LIBRARY ---

function lib.GetSecond(CurrentTime)
	local TSec = CurrentTime % 86400
	local CurrentSecond = math.floor(TSec%60)

	return CurrentSecond;
end

function lib.GetMinute(CurrentTime)
	local TSec = CurrentTime % 86400
	local CurrentMinute = math.floor((TSec/60)%60)
	return CurrentMinute;
end

function lib.GetHour(CurrentTime)
	local TSec = CurrentTime % 86400
	local CurrentHour = math.floor((TSec/60/60)%24)
	return CurrentHour;
end

function lib.GetDay(CurrentTime)
	local CurrentDay = math.ceil(CurrentTime/60/60/24%365.25)
	return CurrentDay;
end

function lib.GetYear(CurrentTime) 
	local CurrentYear = math.floor(CurrentTime/60/60/24/365.25+1970)

	return CurrentYear
end

function lib.GetYearShort(CurrentTime)
	local Year = lib.GetYear(CurrentTime);
	return Year % 100
end

function lib.GetYearShortFormatted(CurrentTime) 
	local ShortYear = lib.GetYearShort(CurrentTime);
	if ShortYear < 10 then
		ShortYear = "0"..ShortYear
	end
	return ShortYear
end

function lib.GetMonth(CurrentTime)
	local Year = lib.GetYear(CurrentTime)
	local Day = lib.GetDay(CurrentTime)
	local Month;
	
	FixLeapYear(Year)
	
	for Index=1, #DaysInMonth do
		if Day > DaysInMonth[Index] then
			Day = Day - DaysInMonth[Index]
		else
			return Index
		end
	end
end

function lib.GetFormattedMonth(CurrentTime)
	local Month = lib.GetMonth(CurrentTime);
	if Month < 10 then
		Month = "0"..Month;
	end
	
	return Month;
end

function lib.GetDayOfTheMonth(CurrentTime)
	local Year = lib.GetYear(CurrentTime)
	local Day = lib.GetDay(CurrentTime)
	local DayOfTheMonth;
	
	FixLeapYear(Year)

	for Index=1, #DaysInMonth do
		if Day > DaysInMonth[Index] then
			Day = Day - DaysInMonth[Index]
		else
			return Day
		end
	end
end

function lib.GetFormattedDayOfTheMonth(CurrentTime)
	local DayOfTheMonth = lib.GetDayOfTheMonth(CurrentTime);
	
	if DayOfTheMonth < 10 then
		DayOfTheMonth = "0"..DayOfTheMonth;
	end
	
	return DayOfTheMonth;
end

function lib.GetMonthName(CurrentTime)
	return MonthNames[lib.GetMonth(CurrentTime)]
end

function lib.GetMonthNameShort(CurrentTime)
	return MonthNamesShort[lib.GetMonth(CurrentTime)]
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
	- 32045);--]]

	return JulianDay
end

function lib.GetDayOfTheWeek(CurrentTime)
	
	local JulianTime = lib.GetJulianDate(CurrentTime);
	
	return math.floor(JulianTime) % 7
end

function lib.GetDayOfTheWeekName(CurrentTime)
	local DayOfTheWeek = lib.GetDayOfTheWeek(CurrentTime)
	local Name = DaysOfTheWeek[DayOfTheWeek]
	
	return Name
end

function lib.GetDayOfTheWeekNameShort(CurrentTime) 
	local DayOfTheWeek = lib.GetDayOfTheWeek(CurrentTime)
	local Name = DaysOfTheWeekShort[DayOfTheWeek] 
	
	return Name
end

function lib.GetOrdinalOfNumber(Number) -- Returns st, nd (Like 1st, 2nd)
	local TenRemainder = Number % 10;
	local HundredRemainder = Number % 100
	
	if HundredRemainder >= 10 and HundredRemainder <= 20 then
		return "th";
	end
	
	if TenRemainder == 1 then
		return "st";
	elseif TenRemainder == 2 then
		return "nd";
	elseif TenRemainder == 3 then
		return "rd";
	else
		return "th";
	end
end

function lib.GetDayOfTheMonthOrdinal(CurrentTime)
	local DayOfTheMonth = lib.GetDayOfTheMonth(CurrentTime)

	return lib.GetOrdinalOfNumber(DayOfTheMonth);
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
		CurrentHour = "0"..CurrentHour;
	end

	return CurrentHour
end

function lib.GetRegularHourFormatted(CurrentTime)
	local CurrentHour = lib.GetRegularHour(CurrentTime)

	if CurrentHour < 10 then
		CurrentHour = "0"..CurrentHour
	end

	return CurrentHour;
end

function lib.GetamOrpm(CurrentTime)
	local CurrentHour = lib.GetHour(CurrentTime)

	if CurrentHour > 12 then
		return "pm";
	else
		return "am";
	end
end

function lib.GetAMorPM(CurrentTime)
	local CurrentHour = lib.GetHour(CurrentTime)

	if CurrentHour > 12 then
		return "PM";
	else
		return "AM";
	end
end

function lib.GetMilitaryHour(CurrentTime)
	local CurrentHour = lib.GetHour(CurrentTime)

	if CurrentHour < 10 then
		CurrentHour = "0"..CurrentHour
	end
end

function lib.LeapYear(CurrentTime)
	local Year = lib.GetYear(CurrentTime);

	if Year % 4 == 0 then
		return 1
	else
		return 0
	end
end

function lib.GetDaysInMonth(CurrentTime)
	local Month = lib.GetMonth(CurrentTime);
	local Year = lib.GetYear(CurrentTime);

	FixLeapYear(Year)

	return DaysInMonth[Month]
end

local FormatStrings = {
	d = lib.GetFormattedDayOfTheMonth;
	D = lib.GetDayOfTheWeekNameShort;
	j = lib.GetDayOfTheMonth;
	l = lib.GetDayOfTheWeekName;
	N = lib.GetDayOfTheWeek;
	S = lib.GetDayOfTheMonthOrdinal;
	W = lib.GetDayOfTheWeek;
	Z = lib.GetDay;

	--W -- Mmm.. Idk. 
	
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
	
	--e -- No way to get Time Zones
	-- I -- Daylight saving time should be added later.
	-- O -- No way to get Time Zones
	-- P -- No way to get Time Zones
	-- T -- No way to get Time Zones
	-- Z -- No way to get Time Zones
	
	-- c -- ISO 8601
	-- r -- No need for formatted dates
	U = time;
}

local MatchString = "["

for Index, Value in pairs(FormatStrings) do
	MatchString = MatchString..Index
end

MatchString = MatchString.."]";

function lib.GetFormattedTime(Format, CurrentTime)
	CurrentTime = CurrentTime or tick();
	
	local ReturnString = Format;
	local FormatsRequired = {}
	
	for NewFormat in string.gmatch(Format, MatchString) do
		FormatsRequired[#FormatsRequired+1] = NewFormat
	end
	
	for _, FormatType in pairs(FormatsRequired) do
		ReturnString = ReturnString:gsub(FormatType, FormatType:rep(3))
	end
	
	for _, FormatType in pairs(FormatsRequired) do
		local Replacement = FormatStrings[FormatType](CurrentTime)
		ReturnString = ReturnString:gsub(FormatType:rep(3), Replacement)
	end
	
	return ReturnString;
end

-- UTCTime handling
local mLastCachedTimeAt = nil
local mLastCachedTime = nil
local mTimeOffset = os.time() - tick()
function lib.UTCTimeExact()
	return tick() + mTimeOffset
end
function lib.UTCTime()
	if game.Workspace.DistributedGameTime ~= mLastCachedTimeAt then
		mLastCachedTime = tick() + mTimeOffset
		mLastCachedTimeAt = game.Workspace.DistributedGameTime
	end
	return mLastCachedTime
end

return lib