--!nonstrict
--[=[
	@class noise

	Smooth Perlin-like value that wanders in [min, max] over time.
	frequency = cycles per second (default 1). Uses Roblox math.noise.

	Frequency may change every frame without popping: we integrate
	phase += dt * frequency instead of sampling (clock * frequency), which
	would jump when frequency changes.

	Call every frame like spring (use a distinct `dis` per independent channel).

	Why math.noise (Perlin-ish): cheap, continuous, good for rock bob / FOV wobble /
	ambient motion. Pitfall — returns 0 when x,y,z are ALL integers — so we keep
	fixed non-integer phase offsets on y/z and only advance x with phase.
	Range is ~[-0.5, 0.5]; we remap + clamp into [min, max].
]=]

local require = require(script.Parent.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local getOrCreateHookState = require("ImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(dis: any?, min: number?, max: number?, frequency: number?): number
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)

		local lo = if min ~= nil then min else 0
		local hi = if max ~= nil then max else 1
		local freq = if frequency ~= nil then frequency else 1

		local now = os.clock()
		if not hookState.noiseInit then
			hookState.noiseInit = true
			hookState.noisePhase = 0
			hookState.noiseLastClock = now
			-- Non-integer y/z so we never hit the all-integer → 0 lattice.
			local rng = Random.new()
			hookState.noiseOy = rng:NextNumber(0.1, 1000)
			hookState.noiseOz = rng:NextNumber(0.1, 1000)
			hookState.noiseOx = rng:NextNumber(0.1, 1000)
		end

		local dt = now - hookState.noiseLastClock
		hookState.noiseLastClock = now
		-- Integrate frequency so changing it mid-flight stays continuous.
		hookState.noisePhase += math.max(dt, 0) * freq

		local n = math.noise(hookState.noisePhase + hookState.noiseOx, hookState.noiseOy, hookState.noiseOz)
		local u = math.clamp(n + 0.5, 0, 1)
		return lo + (hi - lo) * u
	end
end
