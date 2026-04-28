export namespace Time {
  function getDaysMonthTable(year: number): {
    [month: number]: number;
  };
  function getSecond(currentTime: number): number;
  function getMinute(currentTime: number): number;
  function getHour(currentTime: number): number;
  function getDay(currentTime: number): number;
  function getYear(currentTime: number): number;
  function getYearShort(currentTime: number): number;
  function getYearShortFormatted(currentTime: number): string;
  function getMonth(currentTime: number): number | undefined;
  function getFormattedMonth(currentTime: number): string;
  function getDayOfTheMonth(currentTime: number): number | undefined;
  function getFormattedDayOfTheMonth(currentTime: number): string;
  function getMonthName(currentTime: number): string;
  function getMonthNameShort(currentTime: number): string;
  function getJulianDate(currentTime: number): number;
  function getDayOfTheWeek(currentTime: number): number;
  function getDayOfTheWeekName(currentTime: number): string;
  function getDayOfTheWeekNameShort(currentTime: number): string;
  function getOrdinalOfNumber(number: number): string;
  function getDayOfTheMonthOrdinal(currentTime: number): string | undefined;
  function getFormattedSecond(currentTime: number): string;
  function getFormattedMinute(currentTime: number): string;
  function getRegularHour(currentTime: number): number;
  function getHourFormatted(currentTime: number): string;
  function getRegularHourFormatted(currentTime: number): string;
  function getamOrpm(currentTime: number): 'am' | 'pm';
  function getAMorPM(currentTime: number): 'AM' | 'PM';
  function getMilitaryHour(currentTime: number): string;
  function isLeapYear(currentTime: number): boolean;
  function getDaysInMonth(currentTime: number): number;
  function getFormattedTime(format: string, currentTime: number): string;
}
