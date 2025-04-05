--!strict
--[=[
	Authored by Egomoose, modified by Quenty

	@class SwingTwistUtils
]=]

local SwingTwistUtils = {}

--[=[
	Decomposes a CFrame into a swing and a twist.
	@param cf CFrame
	@param direction Vector3
	@return CFrame -- swing
	@return CFrame -- twist
]=]
function SwingTwistUtils.swingTwist(cf: CFrame, direction: Vector3): (CFrame, CFrame)
	local axis, theta = cf:ToAxisAngle()
	-- convert to quaternion
	local w, v = math.cos(theta / 2), math.sin(theta / 2) * axis

	-- (v . d)*d, plug into CFrame quaternion constructor with w it will solve rest for us
	local proj = v:Dot(direction) * direction
	local twist = CFrame.new(0, 0, 0, proj.X, proj.Y, proj.Z, w)

	-- cf = swing * twist, thus...
	local swing = cf * twist:Inverse()

	return swing, twist
end

--[=[
	@param cf CFrame
	@param direction Vector3
	@return number
]=]
function SwingTwistUtils.twistAngle(cf: CFrame, direction: Vector3): number
	local axis, theta = cf:ToAxisAngle()
	local w, v = math.cos(theta/2),  math.sin(theta/2)*axis
	local proj = v:Dot(direction)*direction
	local twist = CFrame.new(0, 0, 0, proj.X, proj.Y, proj.Z, w)
	local _, nTheta = twist:ToAxisAngle()
	return math.sign(v:Dot(direction))*nTheta
end

return SwingTwistUtils