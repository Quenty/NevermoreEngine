--!strict
--[=[
	@class ImmediateHookAverageUtils
]=]
local require = require(script.Parent.loader).load(script)

local ImmediateHookAverageUtils = {}

export type AverageableValue = number | Vector3 | Vector2

function ImmediateHookAverageUtils.zeroSum(sample: AverageableValue): AverageableValue
	local sampleType = typeof(sample)
	if sampleType == "Vector3" then
		return Vector3.zero
	elseif sampleType == "Vector2" then
		return Vector2.zero
	end
	return 0
end

function ImmediateHookAverageUtils.quotient(sum: AverageableValue, count: number): AverageableValue
	if count <= 0 then
		return sum
	end
	return (sum :: any) / count
end

return ImmediateHookAverageUtils
