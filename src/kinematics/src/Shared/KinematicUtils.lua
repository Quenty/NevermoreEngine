--!strict
--[=[
	@class KinematicUtils
]=]

local KinematicUtils = {}

function KinematicUtils.positionVelocity(now: number, t0: number, p0: number, v0: number, a0: number): (number, number)
	local dt = now - t0

	-- stylua: ignore
	return p0 + v0*dt + 0.5*dt*dt*a0,
	       v0 + a0*dt
end

return KinematicUtils
