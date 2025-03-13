--!strict
--[=[
	Function that uses raycasting to determine the groundplane in Roblox.
	@class getGroundPlane
]=]

local require = require(script.Parent.loader).load(script)

local batchRaycast = require("batchRaycast")

local function resolvePlane(basis: CFrame, points: { Vector3 }, norms: { Vector3 }): (Vector3?, Vector3?)
	local n = #points

	--[[
	xx xz xc   u   xy
	xz zz zc x v = yz
	xc zc cc   h   yc
	]]
	local xx, xz, xc = 0, 0, 0
	local zz, zc = 0, 0
	local cc = 0

	local xy, yz, yc = 0, 0, 0

	for i = 1, n do
		local p = basis:PointToObjectSpace(points[i])
		local x = p.X
		local y = p.Y
		local z = p.Z
		xx = xx + x * x
		xz = xz + x * z
		xc = xc + x
		zz = zz + z * z
		zc = zc + z
		cc = cc + 1
		xy = xy + x * y
		yz = yz + y * z
		yc = yc + y
	end

	local det = cc * xx * zz - cc * xz * xz + 2 * xc * xz * zc - xx * zc * zc - xc * xc * zz
	if det * det > 1e-12 then
		local u = (cc * xy * zz - cc * xz * yz + xz * yc * zc + xc * yz * zc - xy * zc * zc - xc * yc * zz) / det
		local v = (cc * xx * yz - cc * xy * xz + xc * xz * yc - xc * xc * yz + xc * xy * zc - xx * yc * zc) / det
		local h = (xc * xz * yz - xz * xz * yc + xy * xz * zc - xx * yz * zc - xc * xy * zz + xx * yc * zz) / det
		local pos = Vector3.new(0, h, 0)
		local nrm = Vector3.new(-u, 1, -v).Unit
		return basis * pos, basis:VectorToWorldSpace(nrm), h, u, v
	end

	local uSum = 0
	local vSum = 0
	for i = 1, n do
		local norm = basis:VectorToObjectSpace(norms[i])
		local x = norm.X
		local y = norm.Y
		local z = norm.Z
		uSum = uSum - x / y
		vSum = vSum - z / y
	end

	if cc ~= 0 then
		local u = uSum / cc
		local v = vSum / cc
		local h = (yc - u * xc - v * zc) / cc
		local pos = Vector3.new(0, h, 0)
		local nrm = Vector3.new(-u, 1, -v).Unit
		return basis * pos, basis:VectorToWorldSpace(nrm), h, u, v
	end

	return nil, nil
end

local goldenAngle = (3 - 5 ^ 0.5) * math.pi

--[=[
	Uses -y as the direction

	Searchs for a groundPlane given a basis. Useful for planting a object
	in 3D space on terrain.

	:::warning
	ignoreFunc REALLY SHOULD NOT YIELD
	:::

	@function getGroundPlane
	@param basis Vector3
	@param radius number
	@param length number
	@param sampleCount number
	@param ignoreFunc (Instance) -> boolean
	@return Vector3 -- position
	@return Vector3 -- normal
	@within getGroundPlane
]=]
local function getGroundPlane(
	basis: CFrame, radius: number, length: number, sampleCount: number,
	ignoreList: { Instance }, ignoreFunc: (Instance) -> boolean
): (Vector3?, Vector3?)
	debug.profilebegin("createRayData")

	local originList = table.create(sampleCount)
	local directionList = table.create(sampleCount)

	local d = basis:VectorToWorldSpace(Vector3.new(0, -length, 0))

	for i = 1, sampleCount do
		local r = radius * math.sqrt((i - 1) / sampleCount)
		local x = r * math.cos(goldenAngle * i)
		local z = r * math.sin(goldenAngle * i)
		local o = basis:PointToWorldSpace(Vector3.new(x, 0, z))

		originList[i] = o
		directionList[i] = d
	end

	debug.profileend()

	debug.profilebegin("batchRaycast")
	local resultList = batchRaycast(originList, directionList, ignoreList, ignoreFunc, false)
	debug.profileend()

	debug.profilebegin("separateRaycastResults")
	local n = 0
	local poses = table.create(sampleCount)
	local norms = table.create(sampleCount)

	for i = 1, sampleCount do
		local result = resultList[i]
		if result then
			n = n + 1
			poses[n] = result.Position
			norms[n] = result.Normal
		end
	end
	debug.profileend()

	debug.profilebegin("resolvePlane")
	local planePosition, planeNormal = resolvePlane(basis, poses, norms)
	debug.profileend()

	return planePosition, planeNormal
end

return getGroundPlane