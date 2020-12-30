local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local batchRaycast = require("batchRaycast")

local function resolvePlane(basis, points, norms)
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
		local p = basis:pointToObjectSpace(points[i])
		local x = p.x
		local y = p.y
		local z = p.z
		xx = xx + x*x
		xz = xz + x*z
		xc = xc + x
		zz = zz + z*z
		zc = zc + z
		cc = cc + 1
		xy = xy + x*y
		yz = yz + y*z
		yc = yc + y
	end

	local det = cc*xx*zz - cc*xz*xz + 2*xc*xz*zc - xx*zc*zc - xc*xc*zz
	if det*det > 1e-12 then
		local u = (cc*xy*zz - cc*xz*yz + xz*yc*zc + xc*yz*zc - xy*zc*zc - xc*yc*zz)/det
		local v = (cc*xx*yz - cc*xy*xz + xc*xz*yc - xc*xc*yz + xc*xy*zc - xx*yc*zc)/det
		local h = (xc*xz*yz - xz*xz*yc + xy*xz*zc - xx*yz*zc - xc*xy*zz + xx*yc*zz)/det
		local pos = Vector3.new(0, h, 0)
		local nrm = Vector3.new(-u, 1, -v).unit
		return basis*pos, basis:vectorToWorldSpace(nrm), h, u, v
	end

	local uSum = 0
	local vSum = 0
	for i = 1, n do
		local norm = basis:vectorToObjectSpace(norms[i])
		local x = norm.x
		local y = norm.y
		local z = norm.z
		uSum = uSum - x/y
		vSum = vSum - z/y
	end

	if cc ~= 0 then
		local u = uSum/cc
		local v = vSum/cc
		local h = (yc - u*xc - v*zc)/cc
		local pos = Vector3.new(0, h, 0)
		local nrm = Vector3.new(-u, 1, -v).unit
		return basis*pos, basis:vectorToWorldSpace(nrm), h, u, v
	end
end


local goldenAngle = (3 - 5^0.5)*math.pi

-- uses -y as the direction
-- ignoreFunc REALLY SHOULD NOT YIELD
local function getGroundPlane(
	basis, radius, length, sampleCount,
	ignoreList, ignoreFunc
)
	debug.profilebegin("create ray data")
	local originList = table.create(sampleCount)
	local directionList = table.create(sampleCount)

	local d = basis:VectorToWorldSpace(Vector3.new(0, -length, 0))

	for i = 1, sampleCount do
		local r = radius*math.sqrt((i - 1)/sampleCount)
		local x = r*math.cos(goldenAngle*i)
		local z = r*math.sin(goldenAngle*i)
		local o = basis:PointToWorldSpace(Vector3.new(x, 0, z))

		originList[i] = o
		directionList[i] = d
	end
	debug.profileend()

	debug.profilebegin("batchRaycast")
	local resultList = batchRaycast(
		originList, directionList,
		ignoreList, ignoreFunc, false
	)
	debug.profileend()

	debug.profilebegin("separate raycast results")
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