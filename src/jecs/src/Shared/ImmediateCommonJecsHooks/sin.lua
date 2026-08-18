--!nonstrict
--[=[
	@class sin

	Oscillating sine in [min, max] (default 0..1).
	frequency = cycles per second (default 1).
	Same signature as noise; phase is integrated so mid-flight freq changes stay continuous.
]=]

local require = require(script.Parent.Parent.loader).load(script)

local JecsImmediateInstall = require("JecsImmediateInstall")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: JecsImmediateInstall.ImmediateRuntime_Jecs)
	return function(dis: any?, min: number?, max: number?, frequency: number?, startPhase: number?): number
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)

		local lo = if min ~= nil then min else 0
		local hi = if max ~= nil then max else 1
		local freq = if frequency ~= nil then frequency else 1

		local now = os.clock() + (startPhase or 0)
		if not hookState.sinInit then
			hookState.sinInit = true
			-- Random phase so sibling sins don't all sync.
			hookState.sinPhase = Random.new():NextNumber(0, 1)
			hookState.sinLastClock = now
		end

		local dt = now - hookState.sinLastClock
		hookState.sinLastClock = now
		hookState.sinPhase += math.max(dt, 0) * freq

		local u = (math.sin(hookState.sinPhase * math.pi * 2) + 1) * 0.5
		return lo + (hi - lo) * u
	end
end
