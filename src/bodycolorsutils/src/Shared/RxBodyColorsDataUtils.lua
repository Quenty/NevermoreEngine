--[=[
	@class RxBodyColorsDataUtils
]=]

local require = require(script.Parent.loader).load(script)

local Rx = require("Rx")
local BodyColorsDataConstants = require("BodyColorsDataConstants")
local RxAttributeUtils = require("RxAttributeUtils")
local BodyColorsDataUtils = require("BodyColorsDataUtils")

local RxBodyColorsDataUtils = {}

--[=[
	Observes the current body colors data from attributes

	@param instance Instance
	@return Observable<BodyColorsData>
]=]
function RxBodyColorsDataUtils.observeFromAttributes(instance)
	assert(typeof(instance) == "Instance", "Bad instance")

	local observables = {}

	for key, attributeName in pairs(BodyColorsDataConstants.ATTRIBUTE_MAPPING) do
		observables[key] = RxAttributeUtils.observeAttribute(instance, attributeName)
	end

	return Rx.combineLatest(observables):Pipe({
		Rx.map(function(latestValues)
			for key, attributeName in pairs(BodyColorsDataConstants.ATTRIBUTE_MAPPING) do
				local bodyColorsData = {}

				local value = latestValues[key]
				if typeof(value) == "Color3" then
					bodyColorsData[key] = value
				else
					warn(string.format("[RxBodyColorsDataUtils.observeFromAttributes] - Bad attribute %q of type %q",
						attributeName,
						typeof(value)))
				end

				return BodyColorsDataUtils.createBodyColorsData(bodyColorsData)
			end
		end);
	})
end

return RxBodyColorsDataUtils