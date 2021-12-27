--[=[
	Utility functions involving RandomVector3Utils
	@class RandomVector3Utils
]=]

local RandomVector3Utils = {}

--[=[
	Equal distribution unit vectors around a sphere
	@return Vector3
]=]
function RandomVector3Utils.getRandomUnitVector()
	local s = 2*(math.random()-0.5)
	local t = 6.2831853071796*math.random()
	local rx = s
	local m = (1-s*s)^0.5
	local ry = m*math.cos(t)
	local rz = m*math.sin(t)
	return Vector3.new(rx, ry, rz)
end

return RandomVector3Utils