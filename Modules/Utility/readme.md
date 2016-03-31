# os
This extends the os table to include os.date! It functions just like Lua's built-in os.date, but with a few additions.

Note: Padding can be toggled by inserting a '_' like so: os.date("%_x", os.time())

Note: tick() is the default unix time used for os.date()

```lua
os.date("*t")
```
returns a table with the following indices:
```
hour    14
min     36
wday    1
year    2003
yday    124
month   5
sec     33
day     4
```
String reference:
```
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
```
os.clock() returns how long the server has been active

Note: os.clock() uses wait() to get how long the server has been active, so the thread will yield momentarily.
