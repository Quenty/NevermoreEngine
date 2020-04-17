---
-- @module LocalAngularInertiaUtils

local LocalAngularInertiaUtils = {}

local MARGIN = 0.05

function LocalAngularInertiaUtils.forPartType(partType, mass, size)
	if partType == Enum.PartType.Block then
		return LocalAngularInertiaUtils.forBox(mass, size)
	elseif partType == Enum.PartType.Ball then
		return LocalAngularInertiaUtils.forBallPartType(mass, size)
	elseif partType == Enum.PartType.Cylinder then
		return LocalAngularInertiaUtils.forCylinderPartType(mass, size)
	else
		error("Bad PartType")
	end
end

function LocalAngularInertiaUtils.forBox(mass, size)
	-- Roblox parts be weird

	local lx = size.x + MARGIN
	local ly = size.y + MARGIN
	local lz = size.z + MARGIN

	return Vector3.new(
		mass/12 * ly*ly + lz*lz,
		mass/12 * lx*lx + lz*lz,
		mass/12 * lx*lx + ly*ly)
end

function LocalAngularInertiaUtils.forCylinderPartType(mass, size)
	local radius = math.min(size.y, size.z)/2
	local height = size.x

	return LocalAngularInertiaUtils.cylinder(mass, radius, height)
end

function LocalAngularInertiaUtils.forBallPartType(mass, size)
	local radius = math.min(size.x, size.y, size.z)/2
	return LocalAngularInertiaUtils.sphere(mass, radius)
end

function LocalAngularInertiaUtils.sphere(mass, radius)
	local x = 0.4*mass*radius*radius
	return Vector3.new(x, x, x)
end

function LocalAngularInertiaUtils.cylinder(mass, radius, height)
	radius = radius + MARGIN
	height = height + MARGIN

	-- assume aligned along x axis
	local radius2 = radius*radius
	local height2 = height*height

	-- calculate tensor terms
	local t1 = mass/12 * height2 + mass/4 * radius2
	local t2 = mass/2 * radius2
	return Vector3.new(t2, t1, t1)
end

return LocalAngularInertiaUtils