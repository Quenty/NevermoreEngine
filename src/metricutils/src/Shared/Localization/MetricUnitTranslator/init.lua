--!strict
--[=[
	Translated unit names and symbols, streamed to each client one locale at a time. A `JSONTranslator` over the
	`<locale>.json` files beside this module, so a player downloads only the English source and their own language.
	Get it from the [ServiceBag] and pass it to [MetricUnit.format] or [RxMetricUnitFormatUtils.observeFormat].

	```lua
	local translator = serviceBag:GetService(require("MetricUnitTranslator"))

	maid:GiveTask(RxMetricUnitFormatUtils.observeFormat(translator, MetricUnit.new(3, "mile"):ToUSCustomary(), {
		unitDisplay = "long",
	}):Subscribe(function(text)
		label.Text = text -- "3 miles", "3 millas", "3 Meilen", "3 мили"
	end))
	```

	Seventeen languages ship, the ones `NumberLocalizationUtils` formats numbers for: English, Spanish, French,
	German, Portuguese, Italian, Russian, Polish, Turkish, Indonesian, Vietnamese, Thai, Arabic, Simplified and
	Traditional Chinese, Japanese and Korean. Every file has every key:

	- `units.<unitId>.long.<category>` and `units.<unitId>.short.<category>` for each of CLDR's plural categories
	  (`zero`, `one`, `two`, `few`, `many`, `other`), picked by [PluralCategoryUtils.getPluralCategory].
	- `per.<timeUnit>.long` and `per.<timeUnit>.short`, where `{n}` is the whole "number unit" before them.

	`{n}` is the number, written for the locale. The files are maintained by hand. English matches
	[MetricUnitDefinitions], which a spec checks; the other languages come from Unicode CLDR's unit patterns (see the
	Unicode notice in this module's source). A no-break space joins a number to its unit.

	@class MetricUnitTranslator
]=]

--[[
	Unicode CLDR data

	The locale files in this folder other than en.json.txt are derived from the Unicode Common Locale Data
	Repository (CLDR), version 49.0.0, as published in the unicode-org/cldr-json repository: the long and short unit
	patterns of cldr-units-full and the cardinal plural rules of cldr-core. PluralCategoryUtils
	implements those plural rules.

	The data was modified: {0} became {n}; U+202F narrow no-break spaces became U+00A0 no-break spaces, and a space
	touching the number became U+00A0; units CLDR does not list (such as square millimetres, kibibytes and radians per
	second) were composed with CLDR's own prefix, per and power2 patterns; and every plural category any shipped
	language uses is filled in every file, a language's other form standing in for categories it does not use. The
	names of the Roblox units (stud, Roblox mass unit) are not CLDR data.

	UNICODE LICENSE V3

	COPYRIGHT AND PERMISSION NOTICE

	Copyright © 2015-2024 Unicode, Inc.

	NOTICE TO USER: Carefully read the following legal agreement. BY
	DOWNLOADING, INSTALLING, COPYING OR OTHERWISE USING DATA FILES, AND/OR
	SOFTWARE, YOU UNEQUIVOCALLY ACCEPT, AND AGREE TO BE BOUND BY, ALL OF THE
	TERMS AND CONDITIONS OF THIS AGREEMENT. IF YOU DO NOT AGREE, DO NOT
	DOWNLOAD, INSTALL, COPY, DISTRIBUTE OR USE THE DATA FILES OR SOFTWARE.

	Permission is hereby granted, free of charge, to any person obtaining a
	copy of data files and any associated documentation (the "Data Files") or
	software and any associated documentation (the "Software") to deal in the
	Data Files or Software without restriction, including without limitation
	the rights to use, copy, modify, merge, publish, distribute, and/or sell
	copies of the Data Files or Software, and to permit persons to whom the
	Data Files or Software are furnished to do so, provided that either (a)
	this copyright and permission notice appear with all copies of the Data
	Files or Software, or (b) this copyright and permission notice appear in
	associated Documentation.

	THE DATA FILES AND SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
	KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF
	THIRD PARTY RIGHTS.

	IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS INCLUDED IN THIS NOTICE
	BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT OR CONSEQUENTIAL DAMAGES,
	OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
	WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
	ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THE DATA
	FILES OR SOFTWARE.

	Except as contained in this notice, the name of a copyright holder shall
	not be used in advertising or otherwise to promote the sale, use or other
	dealings in these Data Files or Software without prior written
	authorization of the copyright holder.

	SPDX-License-Identifier: Unicode-3.0
]]

local require = require(script.Parent.loader).load(script)

-- JSONTranslator.new is typed for its (locale, table) form; this is its documented folder form
return require("JSONTranslator").new("MetricUnitTranslator", script :: any, nil :: any)
