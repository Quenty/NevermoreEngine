--!strict
--[=[
	Converts between linear ratios and decibels. A decibel value is a logarithm, so it is a plain number here rather
	than a [MetricUnit]: decibel gains add where linear ratios multiply, which does not fit MetricUnit's arithmetic.

	Amplitude ratios (a signal's level, such as a voltage or a sample value) use 20 × log10; power ratios use
	10 × log10. Halving the amplitude is about -6 dB; halving the power is about -3 dB.

	```lua
	DecibelUtils.amplitudeToDecibels(0.5) -- -6.0206
	DecibelUtils.decibelsToAmplitude(-6) -- 0.5012
	DecibelUtils.powerToDecibels(2) -- 3.0103
	```

	Check which kind a property is before converting: a volume that scales a signal is an amplitude ratio.

	@class DecibelUtils
]=]

local DecibelUtils = {}

--[=[
	The decibels of an amplitude ratio: `20 × log10(ratio)`. A ratio of 0 is negative infinity (silence).

	@param ratio number -- 1 is unchanged
	@return number
]=]
function DecibelUtils.amplitudeToDecibels(ratio: number): number
	assert(type(ratio) == "number" and ratio >= 0, "Bad ratio")
	if ratio == 0 then
		return -math.huge
	end
	return 20 * math.log10(ratio)
end

--[=[
	The amplitude ratio of a decibel gain: `10 ^ (decibels / 20)`.

	@param decibels number -- 0 is unchanged
	@return number
]=]
function DecibelUtils.decibelsToAmplitude(decibels: number): number
	assert(type(decibels) == "number", "Bad decibels")
	return 10 ^ (decibels / 20)
end

--[=[
	The decibels of a power ratio: `10 × log10(ratio)`. A ratio of 0 is negative infinity.

	@param ratio number -- 1 is unchanged
	@return number
]=]
function DecibelUtils.powerToDecibels(ratio: number): number
	assert(type(ratio) == "number" and ratio >= 0, "Bad ratio")
	if ratio == 0 then
		return -math.huge
	end
	return 10 * math.log10(ratio)
end

--[=[
	The power ratio of a decibel gain: `10 ^ (decibels / 10)`.

	@param decibels number -- 0 is unchanged
	@return number
]=]
function DecibelUtils.decibelsToPower(decibels: number): number
	assert(type(decibels) == "number", "Bad decibels")
	return 10 ^ (decibels / 10)
end

return table.freeze(DecibelUtils)
