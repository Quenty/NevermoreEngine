## Time
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/workflows/lint/badge.svg" alt="Actions Status" />
  </a>
</div>

Library handles time based parsing / operations. Untested. Based off of PHP's time system. Note: This library is out of date, and does not necessarily work. I recommend using os.time()

## Installation
```
npm install @quenty/time --save
```

## Usage
Usage is designed to be simple.

### `Time.getDaysMonthTable(year)`
Returns a Days in months table for the given year

### `Time.getSecond(currentTime)`

### `Time.getMinute(currentTime)`

### `Time.getHour(currentTime)`

### `Time.getDay(currentTime)`

### `Time.getYear(currentTime)`

### `Time.getYearShort(currentTime)`

### `Time.getYearShortFormatted(currentTime)`

### `Time.getMonth(currentTime)`

### `Time.getFormattedMonth(currentTime)`

### `Time.getDayOfTheMonth(currentTime)`

### `Time.getFormattedDayOfTheMonth(currentTime)`

### `Time.getMonthName(currentTime)`

### `Time.getMonthNameShort(currentTime)`

### `Time.getJulianDate(currentTime)`

### `Time.getDayOfTheWeek(currentTime)`

### `Time.getDayOfTheWeekName(currentTime)`

### `Time.getDayOfTheWeekNameShort(currentTime)`

### `Time.getOrdinalOfNumber(number)`

### `Time.getDayOfTheMonthOrdinal(currentTime)`

### `Time.getFormattedSecond(currentTime)`

### `Time.getFormattedMinute(currentTime)`

### `Time.getRegularHour(currentTime)`

### `Time.getHourFormatted(currentTime)`

### `Time.getRegularHourFormatted(currentTime)`

### `Time.getamOrpm(currentTime)`

### `Time.getAMorPM(currentTime)`

### `Time.getMilitaryHour(currentTime)`

### `Time.isLeapYear(currentTime)`

### `Time.getDaysInMonth(currentTime)`

### `Time.getFormattedTime(format, currentTime)`


## Changelog

### 1.0.3
- Added linting via selene and fixed code to respect linting

### 1.0.0
Initial release

### 0.0.0
Initial commit
