---
-- @module SwingTwistUtils
-- @author Egomoose, modified by Quenty

local SwingTwistUtils = {}

function SwingTwistUtils.swingTwist(cf, direction)
    local axis, theta = cf:ToAxisAngle()
    -- convert to quaternion
    local w, v = math.cos(theta/2),  math.sin(theta/2)*axis

    -- (v . d)*d, plug into CFrame quaternion constructor with w it will solve rest for us
	local proj = v:Dot(direction)*direction
    local twist = CFrame.new(0, 0, 0, proj.x, proj.y, proj.z, w)

    -- cf = swing * twist, thus...
	local swing = cf * twist:Inverse()

	return swing, twist
end

function SwingTwistUtils.twistAngle(cf, direction)
    local axis, theta = cf:ToAxisAngle()
    local w, v = math.cos(theta/2),  math.sin(theta/2)*axis
	local proj = v:Dot(direction)*direction
    local twist = CFrame.new(0, 0, 0, proj.x, proj.y, proj.z, w)
    local _, nTheta = twist:ToAxisAngle()
    return math.sign(v:Dot(direction))*nTheta
end

return SwingTwistUtils