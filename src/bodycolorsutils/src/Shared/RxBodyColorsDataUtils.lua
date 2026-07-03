--!strict
--[=[
	@class RxBodyColorsDataUtils
]=]

local require = require(script.Parent.loader).load(script)

local BodyColorsDataConstants = require("BodyColorsDataConstants")
local BodyColorsDataUtils = require("BodyColorsDataUtils")
local Observable = require("Observable")
local Rx = require("Rx")
local RxAttributeUtils = require("RxAttributeUtils")

local RxBodyColorsDataUtils = {}

--[=[
	Observes the current body colors data from attributes

	@param instance Instance
	@return Observable<BodyColorsData>
]=]
function RxBodyColorsDataUtils.observeFromAttributes(
	instance: Instance
): Observable.Observable<BodyColorsDataUtils.BodyColorsData>
	assert(typeof(instance) == "Instance", "Bad instance")

	local observables = {}

	for key, attributeName in BodyColorsDataConstants.ATTRIBUTE_MAPPING :: { [string]: string } do
		observables[key] = RxAttributeUtils.observeAttribute(instance, attributeName)
	end

	return (Rx.combineLatest(observables) :: any):Pipe({
		Rx.map(function(latestValues): any
			local bodyColorsData = {}

			for key, attributeName in BodyColorsDataConstants.ATTRIBUTE_MAPPING :: { [string]: string } do
				local value = latestValues[key]
				if typeof(value) == "Color3" then
					bodyColorsData[key] = value
				else
					warn(
						string.format(
							"[RxBodyColorsDataUtils.observeFromAttributes] - Bad attribute %q of type %q",
							attributeName,
							typeof(value)
						)
					)
				end
			end

			return BodyColorsDataUtils.createBodyColorsData(bodyColorsData)
		end),
	}) :: any
end

return RxBodyColorsDataUtils
