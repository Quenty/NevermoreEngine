---
-- @module SwingTwistUtils
-- @author Egomoose, modified by Quenty

local SwingTwistUtils = {}

local function getRotationBetween(u, v, axis)
    local dot, uxv = u:Dot(v), u:Cross(v)
    if (dot < -0.99999) then return CFrame.fromAxisAngle(axis, math.pi) end
    return CFrame.new(0, 0, 0, uxv.x, uxv.y, uxv.z, 1 + dot)
end

function SwingTwistUtils.getSwingTwist(cf, direction)
	local swing = CFrame.new()
	local rDirection = cf:VectorToWorldSpace(direction)
    if (rDirection:Dot(direction) > -0.99999) then
        -- we don't need to provide a backup axis b/c it will nvr be used
		swing = getRotationBetween(direction, rDirection, nil)
	end
	-- cf = swing * twist, thus...
	local twist = swing:Inverse() * cf
	return swing, twist
end

return SwingTwistUtils