--!strict
--[=[
	The text `tostring` gives a [MetricUnit]: English, SI symbols, four significant figures, and the same in every
	locale, for logs and test failures. Use [MetricUnitFormatUtils] for text a player reads.

	```lua
	MetricUnitDebugFormat.format(5400, { time = 1 }, false) -- "1.5 h"
	MetricUnitDebugFormat.format(1_600_000, { memory = 1, time = -1 }, false) -- "1.6 MB/s"
	MetricUnitDebugFormat.format(278.15, { temperature = 1 }, true) -- "5 °C"
	```

	@class MetricUnitDebugFormat
]=]

local require = require(script.Parent.loader).load(script)

local MetricUnitCatalog = require("MetricUnitCatalog")
local MetricUnitDimensions = require("MetricUnitDimensions")
local MetricUnitScale = require("MetricUnitScale")

local MetricUnitDebugFormat = {}

--[=[
	Debug text for `amount` SI base units of `dimensions`, absolute or a difference.

	@param amount number
	@param dimensions Dimensions
	@param absolute boolean
	@return string
]=]
function MetricUnitDebugFormat.format(
	amount: number,
	dimensions: MetricUnitDimensions.Dimensions,
	absolute: boolean
): string
	if absolute and MetricUnitDimensions.equal(dimensions, MetricUnitDimensions.TEMPERATURE) then
		return MetricUnitDebugFormat.number(amount - MetricUnitScale.CELSIUS_ZERO) .. " °C"
	end
	local text = MetricUnitDebugFormat._relative(amount, dimensions)
	if absolute and MetricUnitDimensions.equal(dimensions, MetricUnitDimensions.TIME) then
		return "epoch + " .. text
	end
	return if absolute then text .. " (absolute)" else text
end

--[=[
	`value` with four significant figures, or whole when it is a thousand or more.

	@param value number
	@return string
]=]
function MetricUnitDebugFormat.number(value: number): string
	if math.abs(value) >= 1_000 and math.abs(value) < 1e15 then
		return string.format("%.0f", value)
	end
	return string.format("%.4g", value)
end

function MetricUnitDebugFormat._relative(amount: number, dimensions: MetricUnitDimensions.Dimensions): string
	if next(dimensions) == nil then
		return MetricUnitDebugFormat.number(amount)
	end

	local ladder = MetricUnitCatalog.getLadder(dimensions)
	if ladder then
		local unit = MetricUnitCatalog.pickFromLadder(amount, ladder)
		return MetricUnitDebugFormat.number(amount / unit.scale) .. " " .. unit.symbol
	end

	if dimensions.time == -1 then
		local per = MetricUnitCatalog.pickPerUnit(amount)
		local numerator = MetricUnitDimensions.combine(dimensions, MetricUnitDimensions.TIME, 1)
		return MetricUnitDebugFormat._relative(amount * per.scale, numerator) .. "/" .. per.symbol
	end

	local names: { string } = {}
	for name in dimensions do
		table.insert(names, name)
	end
	table.sort(names)

	local over: { string } = {}
	local under: { string } = {}
	for _, name in names do
		local exponent = dimensions[name]
		local symbol = MetricUnitCatalog.getBaseSymbol(name)
		local power = math.abs(exponent)
		local part = if power == 1 then symbol else symbol .. "^" .. tostring(power)
		table.insert(if exponent > 0 then over else under, part)
	end

	local text = MetricUnitDebugFormat.number(amount)
	if #over > 0 then
		text ..= " " .. table.concat(over, "·")
	end
	for _, part in under do
		text ..= "/" .. part
	end
	return text
end

return table.freeze(MetricUnitDebugFormat)
