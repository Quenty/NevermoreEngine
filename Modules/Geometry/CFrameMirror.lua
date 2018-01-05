--- Mirrors cframe across plane
-- @classmod CFrameMirror

local CFrameMirror = {}
CFrameMirror.__index = CFrameMirror
CFrameMirror.ClassName = "CFrameMirror"

function CFrameMirror.new()
	local self = setmetatable({}, CFrameMirror)

	return self
end

--- This is the CFrame that things are reflected over. Reflects over the
-- x axis.
function CFrameMirror:SetCFrame(reflectOver)
	self._reflectOver = reflectOver
end

function CFrameMirror:Reflect(cframe)
	local reflectOver = self._reflectOver or error("No reflect over")

	local relativeCFrame = reflectOver:toObjectSpace(cframe) -- Move to object space.
	local x, y, z,
		r00, r01, r02,
		r10, r11, r12,
		r20, r21, r22 = relativeCFrame:components()

	-- Reflect over the x axis.
	local mirror = CFrame.new(-x, y, z,
		r00,  -r01, -r02,
		-r10, r11,  r12,
		-r20, r21,  r22)

	return reflectOver:toWorldSpace(mirror)
end

function CFrameMirror:ReflectVector(vector)
	local reflectOver = self._reflectOver

	local relative = self._reflectOver:vectorToObjectSpace(vector)
	local mirror = Vector3.new(-relative.x, relative.y, relative.z)

	return reflectOver:vectorToWorldSpace(mirror)
end

function CFrameMirror:ReflectPoint(point)
	local reflectOver = self._reflectOver

	local relative = reflectOver:pointToObjectSpace(point)
	local mirror = Vector3.new(-relative.x, relative.y, relative.z)

	return reflectOver:pointToWorldSpace(mirror)
end

function CFrameMirror:ReflectRay(ray)
	local origin = self:ReflectPoint(ray.Origin)
	local direction = self:ReflectVector(ray.Direction)

	return Ray.new(origin, direction)
end

return CFrameMirror