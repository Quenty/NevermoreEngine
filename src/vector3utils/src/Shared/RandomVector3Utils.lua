--!strict
--[=[
	Utility functions involving RandomVector3Utils
	@class RandomVector3Utils
]=]

local RandomVector3Utils = {}

--[=[
	Equal distribution unit vectors around a sphere
	@return Vector3
]=]
function RandomVector3Utils.getRandomUnitVector(): Vector3
	local s = 2 * (math.random() - 0.5)
	local t = 6.2831853071796 * math.random()
	local rx = s
	local m = (1 - s * s) ^ 0.5
	local ry = m * math.cos(t)
	local rz = m * math.sin(t)
	return Vector3.new(rx, ry, rz)
end

local function gaussianRandom(): number
	return math.sqrt(-2 * math.log(1 - math.random())) * math.cos(2 * math.pi * math.random())
end

--[=[
	Computes a gaussian random vector3.

	@param mean Vector3 -- center
	@param spread Vector3 -- std deviation
	@return Vector3
]=]
function RandomVector3Utils.gaussianRandom(mean: Vector3, spread: Vector3): Vector3
	return mean + spread * Vector3.new(gaussianRandom(), gaussianRandom(), gaussianRandom()) / math.sqrt(3)
end

--[=[
	Gets a uniformally distributed random unit vector3 in the direction
	specified.

	@param direction Vector3
	@param angleRad number -- Angle in radians
	@return Vector3
]=]
function RandomVector3Utils.getDirectedRandomUnitVector(direction: Vector3, angleRad: number): Vector3
	assert(typeof(direction) == "Vector3", "Bad direction")
	assert(type(angleRad) == "number", "Bad angleRad")

	local s = 1 - (1 - math.cos(angleRad)) * math.random()
	local t = 6.2831853071796 * math.random()
	local rx = s
	local m = (1 - s * s) ^ 0.5
	local ry = m * math.cos(t)
	local rz = m * math.sin(t)

	local dx, dy, dz = direction.X, direction.Y, direction.Z
	local d = (dx * dx + dy * dy + dz * dz) ^ 0.5

	if dx / d < -0.9999 then
		return Vector3.new(-rx, ry, rz)
	elseif dx / d < 0.9999 then
		local coef1 = (rx - dx * (dy * ry + dz * rz) / (dy * dy + dz * dz)) / d
		local coef2 = (dz * ry - dy * rz) / (dy * dy + dz * dz)
		return Vector3.new((dx * rx + dy * ry + dz * rz) / d, dy * coef1 + dz * coef2, dz * coef1 - dy * coef2)
	else
		return Vector3.new(rx, ry, rz)
	end
end

return RandomVector3Utils
