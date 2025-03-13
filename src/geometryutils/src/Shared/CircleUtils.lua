--!strict
--[=[
	@class CircleUtils
]=]

local CircleUtils = {}

--[=[
	https://math.stackexchange.com/questions/110080/shortest-way-to-achieve-target-angle
	Note: target should be within 0 and circumference

	@param position number
	@param target number
	@param circumference number
	@return number
]=]
function CircleUtils.updatePositionToSmallestDistOnCircle(position: number, target: number, circumference: number): number
	assert(target >= 0 and target <= circumference, "Target must be between 0 and circumference")

	if math.abs(position - target) <= circumference/2 then
		-- No need to force spring update
		return position
	end

	local current = position % circumference

	local offset1 = target - current
	local offset2 = target - current + circumference
	local offset3 = target - current - circumference

	local dist1 = math.abs(offset1)
	local dist2 = math.abs(offset2)
	local dist3 = math.abs(offset3)

	if dist1 < dist2 and dist1 < dist3 then
		return current
	elseif dist2 < dist3 then
		return current - circumference
	else
		return current + circumference
	end
end

return CircleUtils