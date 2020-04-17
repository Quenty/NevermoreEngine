---
-- @module MomentOfInertiaUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local LocalAngularInertiaUtils = require("LocalAngularInertiaUtils")

local MomentOfInertiaUtils = {}

-- F = m*a
-- T = I*a (a is angular accelerator)

function MomentOfInertiaUtils.momentOfInertia(cframe, mass, partType, size, axis, origin)
	local position = cframe.p

	-- Moment that is a Vector3, aligned to the part CFrame
	-- We assume part center of mass is the part center
	local localInertia = LocalAngularInertiaUtils.forPartType(partType, mass, size)
	local worldInertia = cframe:vectorToWorldSpace(localInertia)

	local offset = position - origin
	local radius = offset:Cross(axis)
	local radius2 = radius:Dot(radius)

	-- Point mass...
	return mass*radius2
end

return MomentOfInertiaUtils