--!strict
--[=[
	Observable formatting, for UI that should follow the player's language. Kept apart from
	[MetricUnitFormatUtils] so formatting itself needs no Rx and runs anywhere, servers and specs included.

	@class RxMetricUnitFormatUtils
]=]

local require = require(script.Parent.loader).load(script)

local MetricUnitFormatUtils = require("MetricUnitFormatUtils")
local Observable = require("Observable")
local Rx = require("Rx")

local RxMetricUnitFormatUtils = {}

local ANY_TRANSLATION_KEY = "units.meter.other"

--[=[
	Observes [MetricUnitFormatUtils.format] in the translator's language: emits again when the player's locale
	changes or its translations finish streaming in, with English names until then. Numbers follow the translator's
	locale unless `options.locale` is given.

	```lua
	local translator = serviceBag:GetService(require("MetricUnitTranslator"))
	maid:GiveTask(RxMetricUnitFormatUtils.observeFormat(translator, MetricUnit.new(3, "mile"), {
		unitDisplay = "long",
	}):Subscribe(function(text)
		label.Text = text -- "3 miles", "3 millas", "3 Meilen"
	end))
	```

	@param translator MetricUnitTranslatorLike -- [MetricUnitTranslator]
	@param value MetricUnit | MetricUnitData
	@param options MetricUnitFormatOptions?
	@return Observable<string>
]=]
function RxMetricUnitFormatUtils.observeFormat(
	translator: MetricUnitFormatUtils.MetricUnitTranslatorLike,
	value: any,
	options: MetricUnitFormatUtils.MetricUnitFormatOptions?
): Observable.Observable<string>
	assert(type(translator) == "table" and translator.ObserveFormatByKey, "Bad translator")

	local formatOptions: MetricUnitFormatUtils.MetricUnitFormatOptions = table.clone(options or {})
	formatOptions.translator = translator

	return RxMetricUnitFormatUtils._observeTranslationChanges(translator):Pipe({
		Rx.map(function()
			return MetricUnitFormatUtils.format(value, formatOptions)
		end) :: any,
		Rx.distinct() :: any,
	}) :: any
end

function RxMetricUnitFormatUtils._observeTranslationChanges(
	translator: MetricUnitFormatUtils.MetricUnitTranslatorLike
): Observable.Observable<string>
	return translator:ObserveFormatByKey(ANY_TRANSLATION_KEY, { n = "" })
end

return table.freeze(RxMetricUnitFormatUtils)
