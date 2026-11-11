--!strict
--[=[
	Locale strings for [TimeCalendarUtils], [RelativeTimeUtils] and [TimeDurationUtils], covering
	the same locales as [NumberLocalizationUtils]. Lookups resolve through [ResolveLocaleUtils],
	so `en-gb` lands on English and `es-mx` on Spanish, and an unknown locale falls back to English
	with a warning.

	To add a locale, add one entry to `LOCALES`. Every field is required, so a missing phrase is a
	type error rather than a runtime surprise.

	@class TimeLocalizationUtils
]=]

local require = require(script.Parent.loader).load(script)

local ResolveLocaleUtils = require("ResolveLocaleUtils")

local TimeLocalizationUtils = {}

local DEFAULT_LOCALE = "en-us"

--[=[
	A [Time.format] template, or a function given the time and the reference time that returns
	the finished text.

	@type CalendarFormat string | (dateTime: DateTime, referenceTime: DateTime) -> string
	@within TimeLocalizationUtils
]=]
export type CalendarFormat = string | (DateTime, DateTime) -> string

--[=[
	The phrase [TimeCalendarUtils.calendar] uses for each distance from the reference day.

	@interface CalendarFormats
	.sameDay CalendarFormat
	.nextDay CalendarFormat
	.nextWeek CalendarFormat
	.lastDay CalendarFormat
	.lastWeek CalendarFormat
	.sameElse CalendarFormat
	@within TimeLocalizationUtils
]=]
export type CalendarFormats = {
	sameDay: CalendarFormat,
	nextDay: CalendarFormat,
	nextWeek: CalendarFormat,
	lastDay: CalendarFormat,
	lastWeek: CalendarFormat,
	sameElse: CalendarFormat,
}

--[=[
	A partial [CalendarFormats] a caller passes to override a locale's phrases.

	@type CalendarFormatOverrides { sameDay: CalendarFormat?, nextDay: CalendarFormat?, nextWeek: CalendarFormat?, lastDay: CalendarFormat?, lastWeek: CalendarFormat?, sameElse: CalendarFormat? }
	@within TimeLocalizationUtils
]=]
export type CalendarFormatOverrides = {
	sameDay: CalendarFormat?,
	nextDay: CalendarFormat?,
	nextWeek: CalendarFormat?,
	lastDay: CalendarFormat?,
	lastWeek: CalendarFormat?,
	sameElse: CalendarFormat?,
}

--[=[
	A relative time string with `%d` for the amount, or a function given the
	amount, whether a suffix will be added, the threshold key and whether the time is in the
	future, for languages that inflect.

	@type RelativeTimeString string | (amount: number, withoutSuffix: boolean, key: string, isFuture: boolean) -> string
	@within TimeLocalizationUtils
]=]
export type RelativeTimeString = string | (number, boolean, string, boolean) -> string

--[=[
	Relative time strings for every threshold key. `future` and `past` take `%s`.

	@interface RelativeTimeStrings
	.future string
	.past string
	.s RelativeTimeString
	.m RelativeTimeString
	.mm RelativeTimeString
	.h RelativeTimeString
	.hh RelativeTimeString
	.d RelativeTimeString
	.dd RelativeTimeString
	.M RelativeTimeString
	.MM RelativeTimeString
	.y RelativeTimeString
	.yy RelativeTimeString
	@within TimeLocalizationUtils
]=]
export type RelativeTimeStrings = {
	future: string,
	past: string,
	s: RelativeTimeString,
	m: RelativeTimeString,
	mm: RelativeTimeString,
	h: RelativeTimeString,
	hh: RelativeTimeString,
	d: RelativeTimeString,
	dd: RelativeTimeString,
	M: RelativeTimeString,
	MM: RelativeTimeString,
	y: RelativeTimeString,
	yy: RelativeTimeString,
}

--[=[
	Relative time strings a caller passes to override or extend a locale's, keyed by threshold
	key. Custom thresholds may add their own keys here.

	@type RelativeTimeStringOverrides { [string]: RelativeTimeString }
	@within TimeLocalizationUtils
]=]
export type RelativeTimeStringOverrides = { [string]: RelativeTimeString }

--[=[
	A duration phrase with `%d` for the amount: a singular and plural pair, or a function of the
	amount for languages with more plural forms.

	@type DurationPhrase { one: string, other: string } | (amount: number) -> string
	@within TimeLocalizationUtils
]=]
export type DurationPhrase = { one: string, other: string } | (number) -> string

--[=[
	Duration phrases for every breakdown field.

	@interface DurationStrings
	.years DurationPhrase
	.months DurationPhrase
	.weeks DurationPhrase
	.days DurationPhrase
	.hours DurationPhrase
	.minutes DurationPhrase
	.seconds DurationPhrase
	.milliseconds DurationPhrase
	@within TimeLocalizationUtils
]=]
export type DurationStrings = {
	years: DurationPhrase,
	months: DurationPhrase,
	weeks: DurationPhrase,
	days: DurationPhrase,
	hours: DurationPhrase,
	minutes: DurationPhrase,
	seconds: DurationPhrase,
	milliseconds: DurationPhrase,
}

--[=[
	Duration phrases a caller passes to override a locale's, keyed by breakdown field.

	@type DurationStringOverrides { [string]: DurationPhrase }
	@within TimeLocalizationUtils
]=]
export type DurationStringOverrides = { [string]: DurationPhrase }

--[=[
	Everything one locale needs.

	@interface TimeLocale
	.calendar CalendarFormats
	.relativeTime RelativeTimeStrings
	.duration DurationStrings
	@within TimeLocalizationUtils
]=]
export type TimeLocale = {
	calendar: CalendarFormats,
	relativeTime: RelativeTimeStrings,
	duration: DurationStrings,
}

function TimeLocalizationUtils._withAmount(amount: number, template: string): string
	return (string.gsub(template, "%%d", tostring(amount)))
end

-- Languages without grammatical number use the same phrase for every amount
function TimeLocalizationUtils._invariantPhrase(template: string): DurationPhrase
	return { one = template, other = template }
end

-- Russian style: 1, 21, 31 are singular; 2-4, 22-24 are few; the rest (incl. 11-14) are many
function TimeLocalizationUtils._russianPlural(amount: number, one: string, few: string, many: string): string
	local tens = amount % 100
	local ones = amount % 10
	if ones == 1 and tens ~= 11 then
		return one
	elseif ones >= 2 and ones <= 4 and (tens < 10 or tens >= 20) then
		return few
	else
		return many
	end
end

-- Polish style: only exactly 1 is singular; 2-4, 22-24 are few; the rest are many
function TimeLocalizationUtils._polishPlural(amount: number, one: string, few: string, many: string): string
	if amount == 1 then
		return one
	end

	local tens = amount % 100
	local ones = amount % 10
	if ones >= 2 and ones <= 4 and (tens < 10 or tens >= 20) then
		return few
	else
		return many
	end
end

function TimeLocalizationUtils._russianDuration(one: string, few: string, many: string): DurationPhrase
	return function(amount: number): string
		return amount .. " " .. TimeLocalizationUtils._russianPlural(math.abs(amount), one, few, many)
	end
end

function TimeLocalizationUtils._polishDuration(one: string, few: string, many: string): DurationPhrase
	return function(amount: number): string
		return amount .. " " .. TimeLocalizationUtils._polishPlural(math.abs(amount), one, few, many)
	end
end

-- German: nominative on its own, dative after "in" / "vor"
local GERMAN_RELATIVE_FORMS: { [string]: { string } } = {
	m = { "eine Minute", "einer Minute" },
	h = { "eine Stunde", "einer Stunde" },
	d = { "ein Tag", "einem Tag" },
	dd = { "%d Tage", "%d Tagen" },
	M = { "ein Monat", "einem Monat" },
	MM = { "%d Monate", "%d Monaten" },
	y = { "ein Jahr", "einem Jahr" },
	yy = { "%d Jahre", "%d Jahren" },
}

function TimeLocalizationUtils._germanRelative(
	amount: number,
	withoutSuffix: boolean,
	key: string,
	_isFuture: boolean
): string
	local forms = GERMAN_RELATIVE_FORMS[key]
	return TimeLocalizationUtils._withAmount(amount, if withoutSuffix then forms[1] else forms[2])
end

local RUSSIAN_RELATIVE_FORMS: { [string]: { string } } = {
	mm = { "минута", "минуты", "минут" },
	hh = { "час", "часа", "часов" },
	dd = { "день", "дня", "дней" },
	MM = { "месяц", "месяца", "месяцев" },
	yy = { "год", "года", "лет" },
}

function TimeLocalizationUtils._russianRelative(
	amount: number,
	withoutSuffix: boolean,
	key: string,
	_isFuture: boolean
): string
	if key == "m" then
		return if withoutSuffix then "минута" else "минуту"
	end

	local forms = RUSSIAN_RELATIVE_FORMS[key]
	-- "минуту" is the accusative used after "через" / before "назад"
	local one = if key == "mm" and not withoutSuffix then "минуту" else forms[1]
	return amount .. " " .. TimeLocalizationUtils._russianPlural(amount, one, forms[2], forms[3])
end

function TimeLocalizationUtils._polishRelative(
	amount: number,
	withoutSuffix: boolean,
	key: string,
	_isFuture: boolean
): string
	if key == "m" then
		return if withoutSuffix then "minuta" else "minutę"
	elseif key == "h" then
		return if withoutSuffix then "godzina" else "godzinę"
	elseif key == "mm" then
		return amount .. " " .. TimeLocalizationUtils._polishPlural(amount, "minuta", "minuty", "minut")
	elseif key == "hh" then
		return amount .. " " .. TimeLocalizationUtils._polishPlural(amount, "godzina", "godziny", "godzin")
	elseif key == "MM" then
		return amount .. " " .. TimeLocalizationUtils._polishPlural(amount, "miesiąc", "miesiące", "miesięcy")
	elseif key == "yy" then
		return amount .. " " .. TimeLocalizationUtils._polishPlural(amount, "rok", "lata", "lat")
	else
		error(string.format("No Polish relative form for %q", key))
	end
end

local LOCALES: { [string]: TimeLocale } = {
	en = {
		calendar = {
			sameDay = "[Today at] LT",
			nextDay = "[Tomorrow at] LT",
			nextWeek = "dddd [at] LT",
			lastDay = "[Yesterday at] LT",
			lastWeek = "[Last] dddd [at] LT",
			sameElse = "L",
		},
		relativeTime = {
			future = "in %s",
			past = "%s ago",
			s = "a few seconds",
			m = "a minute",
			mm = "%d minutes",
			h = "an hour",
			hh = "%d hours",
			d = "a day",
			dd = "%d days",
			M = "a month",
			MM = "%d months",
			y = "a year",
			yy = "%d years",
		},
		duration = {
			years = { one = "%d year", other = "%d years" },
			months = { one = "%d month", other = "%d months" },
			weeks = { one = "%d week", other = "%d weeks" },
			days = { one = "%d day", other = "%d days" },
			hours = { one = "%d hour", other = "%d hours" },
			minutes = { one = "%d minute", other = "%d minutes" },
			seconds = { one = "%d second", other = "%d seconds" },
			milliseconds = { one = "%d millisecond", other = "%d milliseconds" },
		},
	},

	es = {
		calendar = {
			sameDay = "[hoy a las] LT",
			nextDay = "[mañana a las] LT",
			nextWeek = "dddd [a las] LT",
			lastDay = "[ayer a las] LT",
			lastWeek = "[el] dddd [pasado a las] LT",
			sameElse = "L",
		},
		relativeTime = {
			future = "en %s",
			past = "hace %s",
			s = "unos segundos",
			m = "un minuto",
			mm = "%d minutos",
			h = "una hora",
			hh = "%d horas",
			d = "un día",
			dd = "%d días",
			M = "un mes",
			MM = "%d meses",
			y = "un año",
			yy = "%d años",
		},
		duration = {
			years = { one = "%d año", other = "%d años" },
			months = { one = "%d mes", other = "%d meses" },
			weeks = { one = "%d semana", other = "%d semanas" },
			days = { one = "%d día", other = "%d días" },
			hours = { one = "%d hora", other = "%d horas" },
			minutes = { one = "%d minuto", other = "%d minutos" },
			seconds = { one = "%d segundo", other = "%d segundos" },
			milliseconds = { one = "%d milisegundo", other = "%d milisegundos" },
		},
	},

	fr = {
		calendar = {
			sameDay = "[Aujourd’hui à] LT",
			nextDay = "[Demain à] LT",
			nextWeek = "dddd [à] LT",
			lastDay = "[Hier à] LT",
			lastWeek = "dddd [dernier à] LT",
			sameElse = "L",
		},
		relativeTime = {
			future = "dans %s",
			past = "il y a %s",
			s = "quelques secondes",
			m = "une minute",
			mm = "%d minutes",
			h = "une heure",
			hh = "%d heures",
			d = "un jour",
			dd = "%d jours",
			M = "un mois",
			MM = "%d mois",
			y = "un an",
			yy = "%d ans",
		},
		duration = {
			years = { one = "%d an", other = "%d ans" },
			months = { one = "%d mois", other = "%d mois" },
			weeks = { one = "%d semaine", other = "%d semaines" },
			days = { one = "%d jour", other = "%d jours" },
			hours = { one = "%d heure", other = "%d heures" },
			minutes = { one = "%d minute", other = "%d minutes" },
			seconds = { one = "%d seconde", other = "%d secondes" },
			milliseconds = { one = "%d milliseconde", other = "%d millisecondes" },
		},
	},

	de = {
		calendar = {
			sameDay = "[heute um] LT [Uhr]",
			nextDay = "[morgen um] LT [Uhr]",
			nextWeek = "dddd [um] LT [Uhr]",
			lastDay = "[gestern um] LT [Uhr]",
			lastWeek = "[letzten] dddd [um] LT [Uhr]",
			sameElse = "L",
		},
		relativeTime = {
			future = "in %s",
			past = "vor %s",
			s = "ein paar Sekunden",
			m = TimeLocalizationUtils._germanRelative,
			mm = "%d Minuten",
			h = TimeLocalizationUtils._germanRelative,
			hh = "%d Stunden",
			d = TimeLocalizationUtils._germanRelative,
			dd = TimeLocalizationUtils._germanRelative,
			M = TimeLocalizationUtils._germanRelative,
			MM = TimeLocalizationUtils._germanRelative,
			y = TimeLocalizationUtils._germanRelative,
			yy = TimeLocalizationUtils._germanRelative,
		},
		duration = {
			years = { one = "%d Jahr", other = "%d Jahre" },
			months = { one = "%d Monat", other = "%d Monate" },
			weeks = { one = "%d Woche", other = "%d Wochen" },
			days = { one = "%d Tag", other = "%d Tage" },
			hours = { one = "%d Stunde", other = "%d Stunden" },
			minutes = { one = "%d Minute", other = "%d Minuten" },
			seconds = { one = "%d Sekunde", other = "%d Sekunden" },
			milliseconds = { one = "%d Millisekunde", other = "%d Millisekunden" },
		},
	},

	pt = {
		calendar = {
			sameDay = "[Hoje às] LT",
			nextDay = "[Amanhã às] LT",
			nextWeek = "dddd [às] LT",
			lastDay = "[Ontem às] LT",
			lastWeek = "dddd [passado às] LT",
			sameElse = "L",
		},
		relativeTime = {
			future = "em %s",
			past = "há %s",
			s = "poucos segundos",
			m = "um minuto",
			mm = "%d minutos",
			h = "uma hora",
			hh = "%d horas",
			d = "um dia",
			dd = "%d dias",
			M = "um mês",
			MM = "%d meses",
			y = "um ano",
			yy = "%d anos",
		},
		duration = {
			years = { one = "%d ano", other = "%d anos" },
			months = { one = "%d mês", other = "%d meses" },
			weeks = { one = "%d semana", other = "%d semanas" },
			days = { one = "%d dia", other = "%d dias" },
			hours = { one = "%d hora", other = "%d horas" },
			minutes = { one = "%d minuto", other = "%d minutos" },
			seconds = { one = "%d segundo", other = "%d segundos" },
			milliseconds = { one = "%d milissegundo", other = "%d milissegundos" },
		},
	},

	it = {
		calendar = {
			sameDay = "[Oggi alle] LT",
			nextDay = "[Domani alle] LT",
			nextWeek = "dddd [alle] LT",
			lastDay = "[Ieri alle] LT",
			lastWeek = "[lo scorso] dddd [alle] LT",
			sameElse = "L",
		},
		relativeTime = {
			future = "tra %s",
			past = "%s fa",
			s = "qualche secondo",
			m = "un minuto",
			mm = "%d minuti",
			h = "un'ora",
			hh = "%d ore",
			d = "un giorno",
			dd = "%d giorni",
			M = "un mese",
			MM = "%d mesi",
			y = "un anno",
			yy = "%d anni",
		},
		duration = {
			years = { one = "%d anno", other = "%d anni" },
			months = { one = "%d mese", other = "%d mesi" },
			weeks = { one = "%d settimana", other = "%d settimane" },
			days = { one = "%d giorno", other = "%d giorni" },
			hours = { one = "%d ora", other = "%d ore" },
			minutes = { one = "%d minuto", other = "%d minuti" },
			seconds = { one = "%d secondo", other = "%d secondi" },
			milliseconds = { one = "%d millisecondo", other = "%d millisecondi" },
		},
	},

	ru = {
		calendar = {
			sameDay = "[Сегодня, в] LT",
			nextDay = "[Завтра, в] LT",
			nextWeek = "[В следующий] dddd, [в] LT",
			lastDay = "[Вчера, в] LT",
			lastWeek = "[В прошлый] dddd, [в] LT",
			sameElse = "L",
		},
		relativeTime = {
			future = "через %s",
			past = "%s назад",
			s = "несколько секунд",
			m = TimeLocalizationUtils._russianRelative,
			mm = TimeLocalizationUtils._russianRelative,
			h = "час",
			hh = TimeLocalizationUtils._russianRelative,
			d = "день",
			dd = TimeLocalizationUtils._russianRelative,
			M = "месяц",
			MM = TimeLocalizationUtils._russianRelative,
			y = "год",
			yy = TimeLocalizationUtils._russianRelative,
		},
		duration = {
			years = TimeLocalizationUtils._russianDuration("год", "года", "лет"),
			months = TimeLocalizationUtils._russianDuration("месяц", "месяца", "месяцев"),
			weeks = TimeLocalizationUtils._russianDuration("неделя", "недели", "недель"),
			days = TimeLocalizationUtils._russianDuration("день", "дня", "дней"),
			hours = TimeLocalizationUtils._russianDuration("час", "часа", "часов"),
			minutes = TimeLocalizationUtils._russianDuration("минута", "минуты", "минут"),
			seconds = TimeLocalizationUtils._russianDuration("секунда", "секунды", "секунд"),
			milliseconds = TimeLocalizationUtils._russianDuration(
				"миллисекунда",
				"миллисекунды",
				"миллисекунд"
			),
		},
	},

	pl = {
		calendar = {
			sameDay = "[Dziś o] LT",
			nextDay = "[Jutro o] LT",
			nextWeek = "[W] dddd [o] LT",
			lastDay = "[Wczoraj o] LT",
			lastWeek = "[W zeszły] dddd [o] LT",
			sameElse = "L",
		},
		relativeTime = {
			future = "za %s",
			past = "%s temu",
			s = "kilka sekund",
			m = TimeLocalizationUtils._polishRelative,
			mm = TimeLocalizationUtils._polishRelative,
			h = TimeLocalizationUtils._polishRelative,
			hh = TimeLocalizationUtils._polishRelative,
			d = "1 dzień",
			dd = "%d dni",
			M = "miesiąc",
			MM = TimeLocalizationUtils._polishRelative,
			y = "rok",
			yy = TimeLocalizationUtils._polishRelative,
		},
		duration = {
			years = TimeLocalizationUtils._polishDuration("rok", "lata", "lat"),
			months = TimeLocalizationUtils._polishDuration("miesiąc", "miesiące", "miesięcy"),
			weeks = TimeLocalizationUtils._polishDuration("tydzień", "tygodnie", "tygodni"),
			days = TimeLocalizationUtils._polishDuration("dzień", "dni", "dni"),
			hours = TimeLocalizationUtils._polishDuration("godzina", "godziny", "godzin"),
			minutes = TimeLocalizationUtils._polishDuration("minuta", "minuty", "minut"),
			seconds = TimeLocalizationUtils._polishDuration("sekunda", "sekundy", "sekund"),
			milliseconds = TimeLocalizationUtils._polishDuration("milisekunda", "milisekundy", "milisekund"),
		},
	},

	tr = {
		calendar = {
			sameDay = "[bugün saat] LT",
			nextDay = "[yarın saat] LT",
			nextWeek = "[gelecek] dddd [saat] LT",
			lastDay = "[dün] LT",
			lastWeek = "[geçen] dddd [saat] LT",
			sameElse = "L",
		},
		relativeTime = {
			future = "%s sonra",
			past = "%s önce",
			s = "birkaç saniye",
			m = "bir dakika",
			mm = "%d dakika",
			h = "bir saat",
			hh = "%d saat",
			d = "bir gün",
			dd = "%d gün",
			M = "bir ay",
			MM = "%d ay",
			y = "bir yıl",
			yy = "%d yıl",
		},
		duration = {
			years = TimeLocalizationUtils._invariantPhrase("%d yıl"),
			months = TimeLocalizationUtils._invariantPhrase("%d ay"),
			weeks = TimeLocalizationUtils._invariantPhrase("%d hafta"),
			days = TimeLocalizationUtils._invariantPhrase("%d gün"),
			hours = TimeLocalizationUtils._invariantPhrase("%d saat"),
			minutes = TimeLocalizationUtils._invariantPhrase("%d dakika"),
			seconds = TimeLocalizationUtils._invariantPhrase("%d saniye"),
			milliseconds = TimeLocalizationUtils._invariantPhrase("%d milisaniye"),
		},
	},

	id = {
		calendar = {
			sameDay = "[Hari ini pukul] LT",
			nextDay = "[Besok pukul] LT",
			nextWeek = "dddd [pukul] LT",
			lastDay = "[Kemarin pukul] LT",
			lastWeek = "dddd [lalu pukul] LT",
			sameElse = "L",
		},
		relativeTime = {
			future = "dalam %s",
			past = "%s yang lalu",
			s = "beberapa detik",
			m = "semenit",
			mm = "%d menit",
			h = "sejam",
			hh = "%d jam",
			d = "sehari",
			dd = "%d hari",
			M = "sebulan",
			MM = "%d bulan",
			y = "setahun",
			yy = "%d tahun",
		},
		duration = {
			years = TimeLocalizationUtils._invariantPhrase("%d tahun"),
			months = TimeLocalizationUtils._invariantPhrase("%d bulan"),
			weeks = TimeLocalizationUtils._invariantPhrase("%d minggu"),
			days = TimeLocalizationUtils._invariantPhrase("%d hari"),
			hours = TimeLocalizationUtils._invariantPhrase("%d jam"),
			minutes = TimeLocalizationUtils._invariantPhrase("%d menit"),
			seconds = TimeLocalizationUtils._invariantPhrase("%d detik"),
			milliseconds = TimeLocalizationUtils._invariantPhrase("%d milidetik"),
		},
	},

	vi = {
		calendar = {
			sameDay = "[Hôm nay lúc] LT",
			nextDay = "[Ngày mai lúc] LT",
			nextWeek = "dddd [tuần tới lúc] LT",
			lastDay = "[Hôm qua lúc] LT",
			lastWeek = "dddd [tuần trước lúc] LT",
			sameElse = "L",
		},
		relativeTime = {
			future = "%s tới",
			past = "%s trước",
			s = "vài giây",
			m = "một phút",
			mm = "%d phút",
			h = "một giờ",
			hh = "%d giờ",
			d = "một ngày",
			dd = "%d ngày",
			M = "một tháng",
			MM = "%d tháng",
			y = "một năm",
			yy = "%d năm",
		},
		duration = {
			years = TimeLocalizationUtils._invariantPhrase("%d năm"),
			months = TimeLocalizationUtils._invariantPhrase("%d tháng"),
			weeks = TimeLocalizationUtils._invariantPhrase("%d tuần"),
			days = TimeLocalizationUtils._invariantPhrase("%d ngày"),
			hours = TimeLocalizationUtils._invariantPhrase("%d giờ"),
			minutes = TimeLocalizationUtils._invariantPhrase("%d phút"),
			seconds = TimeLocalizationUtils._invariantPhrase("%d giây"),
			milliseconds = TimeLocalizationUtils._invariantPhrase("%d mili giây"),
		},
	},

	th = {
		calendar = {
			sameDay = "[วันนี้ เวลา] LT",
			nextDay = "[พรุ่งนี้ เวลา] LT",
			nextWeek = "dddd[หน้า เวลา] LT",
			lastDay = "[เมื่อวานนี้ เวลา] LT",
			lastWeek = "[วัน]dddd[ที่แล้ว เวลา] LT",
			sameElse = "L",
		},
		relativeTime = {
			future = "อีก %s",
			past = "%sที่แล้ว",
			s = "ไม่กี่วินาที",
			m = "1 นาที",
			mm = "%d นาที",
			h = "1 ชั่วโมง",
			hh = "%d ชั่วโมง",
			d = "1 วัน",
			dd = "%d วัน",
			M = "1 เดือน",
			MM = "%d เดือน",
			y = "1 ปี",
			yy = "%d ปี",
		},
		duration = {
			years = TimeLocalizationUtils._invariantPhrase("%d ปี"),
			months = TimeLocalizationUtils._invariantPhrase("%d เดือน"),
			weeks = TimeLocalizationUtils._invariantPhrase("%d สัปดาห์"),
			days = TimeLocalizationUtils._invariantPhrase("%d วัน"),
			hours = TimeLocalizationUtils._invariantPhrase("%d ชั่วโมง"),
			minutes = TimeLocalizationUtils._invariantPhrase("%d นาที"),
			seconds = TimeLocalizationUtils._invariantPhrase("%d วินาที"),
			milliseconds = TimeLocalizationUtils._invariantPhrase("%d มิลลิวินาที"),
		},
	},

	ar = {
		calendar = {
			sameDay = "[اليوم عند الساعة] LT",
			nextDay = "[غدًا عند الساعة] LT",
			nextWeek = "dddd [عند الساعة] LT",
			lastDay = "[أمس عند الساعة] LT",
			lastWeek = "dddd [عند الساعة] LT",
			sameElse = "L",
		},
		relativeTime = {
			future = "بعد %s",
			past = "منذ %s",
			s = "ثانية واحدة",
			m = "دقيقة واحدة",
			mm = "%d دقائق",
			h = "ساعة واحدة",
			hh = "%d ساعات",
			d = "يوم واحد",
			dd = "%d أيام",
			M = "شهر واحد",
			MM = "%d أشهر",
			y = "عام واحد",
			yy = "%d أعوام",
		},
		duration = {
			years = { one = "%d سنة", other = "%d سنوات" },
			months = { one = "%d شهر", other = "%d أشهر" },
			weeks = { one = "%d أسبوع", other = "%d أسابيع" },
			days = { one = "%d يوم", other = "%d أيام" },
			hours = { one = "%d ساعة", other = "%d ساعات" },
			minutes = { one = "%d دقيقة", other = "%d دقائق" },
			seconds = { one = "%d ثانية", other = "%d ثوان" },
			milliseconds = { one = "%d مللي ثانية", other = "%d مللي ثانية" },
		},
	},

	["zh-cn"] = {
		calendar = {
			sameDay = "[今天]LT",
			nextDay = "[明天]LT",
			nextWeek = "[下]dddLT",
			lastDay = "[昨天]LT",
			lastWeek = "[上]dddLT",
			sameElse = "L",
		},
		relativeTime = {
			future = "%s内",
			past = "%s前",
			s = "几秒",
			m = "1 分钟",
			mm = "%d 分钟",
			h = "1 小时",
			hh = "%d 小时",
			d = "1 天",
			dd = "%d 天",
			M = "1 个月",
			MM = "%d 个月",
			y = "1 年",
			yy = "%d 年",
		},
		duration = {
			years = TimeLocalizationUtils._invariantPhrase("%d 年"),
			months = TimeLocalizationUtils._invariantPhrase("%d 个月"),
			weeks = TimeLocalizationUtils._invariantPhrase("%d 周"),
			days = TimeLocalizationUtils._invariantPhrase("%d 天"),
			hours = TimeLocalizationUtils._invariantPhrase("%d 小时"),
			minutes = TimeLocalizationUtils._invariantPhrase("%d 分钟"),
			seconds = TimeLocalizationUtils._invariantPhrase("%d 秒"),
			milliseconds = TimeLocalizationUtils._invariantPhrase("%d 毫秒"),
		},
	},

	["zh-tw"] = {
		calendar = {
			sameDay = "[今天] LT",
			nextDay = "[明天] LT",
			nextWeek = "[下]dddd LT",
			lastDay = "[昨天] LT",
			lastWeek = "[上]dddd LT",
			sameElse = "L",
		},
		relativeTime = {
			future = "%s後",
			past = "%s前",
			s = "幾秒",
			m = "1 分鐘",
			mm = "%d 分鐘",
			h = "1 小時",
			hh = "%d 小時",
			d = "1 天",
			dd = "%d 天",
			M = "1 個月",
			MM = "%d 個月",
			y = "1 年",
			yy = "%d 年",
		},
		duration = {
			years = TimeLocalizationUtils._invariantPhrase("%d 年"),
			months = TimeLocalizationUtils._invariantPhrase("%d 個月"),
			weeks = TimeLocalizationUtils._invariantPhrase("%d 週"),
			days = TimeLocalizationUtils._invariantPhrase("%d 天"),
			hours = TimeLocalizationUtils._invariantPhrase("%d 小時"),
			minutes = TimeLocalizationUtils._invariantPhrase("%d 分鐘"),
			seconds = TimeLocalizationUtils._invariantPhrase("%d 秒"),
			milliseconds = TimeLocalizationUtils._invariantPhrase("%d 毫秒"),
		},
	},

	ko = {
		calendar = {
			sameDay = "[오늘] LT",
			nextDay = "[내일] LT",
			nextWeek = "dddd LT",
			lastDay = "[어제] LT",
			lastWeek = "[지난주] dddd LT",
			sameElse = "L",
		},
		relativeTime = {
			future = "%s 후",
			past = "%s 전",
			s = "몇 초",
			m = "1분",
			mm = "%d분",
			h = "한 시간",
			hh = "%d시간",
			d = "하루",
			dd = "%d일",
			M = "한 달",
			MM = "%d달",
			y = "일 년",
			yy = "%d년",
		},
		duration = {
			years = TimeLocalizationUtils._invariantPhrase("%d년"),
			months = TimeLocalizationUtils._invariantPhrase("%d개월"),
			weeks = TimeLocalizationUtils._invariantPhrase("%d주"),
			days = TimeLocalizationUtils._invariantPhrase("%d일"),
			hours = TimeLocalizationUtils._invariantPhrase("%d시간"),
			minutes = TimeLocalizationUtils._invariantPhrase("%d분"),
			seconds = TimeLocalizationUtils._invariantPhrase("%d초"),
			milliseconds = TimeLocalizationUtils._invariantPhrase("%d밀리초"),
		},
	},

	ja = {
		calendar = {
			sameDay = "[今日] LT",
			nextDay = "[明日] LT",
			nextWeek = "[来週]dddd LT",
			lastDay = "[昨日] LT",
			lastWeek = "[先週]dddd LT",
			sameElse = "L",
		},
		relativeTime = {
			future = "%s後",
			past = "%s前",
			s = "数秒",
			m = "1分",
			mm = "%d分",
			h = "1時間",
			hh = "%d時間",
			d = "1日",
			dd = "%d日",
			M = "1ヶ月",
			MM = "%dヶ月",
			y = "1年",
			yy = "%d年",
		},
		duration = {
			years = TimeLocalizationUtils._invariantPhrase("%d年"),
			months = TimeLocalizationUtils._invariantPhrase("%dヶ月"),
			weeks = TimeLocalizationUtils._invariantPhrase("%d週間"),
			days = TimeLocalizationUtils._invariantPhrase("%d日"),
			hours = TimeLocalizationUtils._invariantPhrase("%d時間"),
			minutes = TimeLocalizationUtils._invariantPhrase("%d分"),
			seconds = TimeLocalizationUtils._invariantPhrase("%d秒"),
			milliseconds = TimeLocalizationUtils._invariantPhrase("%dミリ秒"),
		},
	},
}

for _, locale in pairs(LOCALES) do
	table.freeze(locale.calendar)
	table.freeze(locale.relativeTime)
	table.freeze(locale.duration)
	table.freeze(locale)
end

-- Roblox's Simplified Chinese variant id, same strings as zh-cn
LOCALES["zh-cjv"] = LOCALES["zh-cn"]

--[=[
	Returns the read-only [TimeLocale] for a locale, defaulting to English.
]=]
function TimeLocalizationUtils.getLocale(locale: string?): TimeLocale
	local key = ResolveLocaleUtils.resolveClosestKey(locale or DEFAULT_LOCALE, LOCALES)
	if key then
		return LOCALES[key]
	end

	warn(
		string.format(
			"[TimeLocalizationUtils] - No strings for locale '%s', reverting to '%s' instead.",
			tostring(locale),
			DEFAULT_LOCALE
		)
	)
	return LOCALES[ResolveLocaleUtils.resolveClosestKey(DEFAULT_LOCALE, LOCALES) :: string]
end

--[=[
	Returns the read-only [CalendarFormats] for a locale, defaulting to English.
]=]
function TimeLocalizationUtils.getCalendarFormatsForLocale(locale: string?): CalendarFormats
	return TimeLocalizationUtils.getLocale(locale).calendar
end

--[=[
	Returns the read-only [RelativeTimeStrings] for a locale, defaulting to English.
]=]
function TimeLocalizationUtils.getRelativeTimeStringsForLocale(locale: string?): RelativeTimeStrings
	return TimeLocalizationUtils.getLocale(locale).relativeTime
end

--[=[
	Returns the read-only [DurationStrings] for a locale, defaulting to English.
]=]
function TimeLocalizationUtils.getDurationStringsForLocale(locale: string?): DurationStrings
	return TimeLocalizationUtils.getLocale(locale).duration
end

return TimeLocalizationUtils
