--[=[
	@class KinematicUtils
]=]

local KinematicUtils = {}

function KinematicUtils.positionVelocity(now, t0, p0, v0, a0)
	local dt = now - t0
	return p0 + v0*dt + 0.5*dt*dt*a0,
	       v0 + a0*dt
end

return KinematicUtils