--!nonstrict
--[=[
	@class linearWalk

	Moves the current value toward `goal` at a constant rate of `speed` units/second.
	Supports number / Vector2 / Vector3 / Color3 / CFrame.
	Clamps onto the goal; snaps when within epsilon. Retargets immediately if goal changes.

	CFrame: speed is studs/sec along Position; orientation follows via CFrame:Lerp with the
	same alpha (so pose finishes with the position walk).

	Optional `duration` (first call only): measures distance to the initial goal and locks
	speed to distance/duration for the lifetime of this hook. Later speed args are ignored.
]=]

local require = require(script.Parent.Parent.loader).load(script)

local JecsImmediateHookUtils = require("JecsImmediateHookUtils")
local JecsImmediateInstall = require("JecsImmediateInstall")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

local LINEAR_WALK_EPSILON = 1e-4

return function(rt: JecsImmediateInstall.ImmediateRuntime_Jecs)
	return function(dis: any?, goal: any?, value: any?, speed: number?, duration: number?): any
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)

		if hookState.linearWalkIsCFrame == nil then
			hookState.linearWalkIsCFrame = (goal ~= nil and typeof(goal) == "CFrame")
				or (value ~= nil and typeof(value) == "CFrame")
		end
		local isCFrame = hookState.linearWalkIsCFrame

		if isCFrame then
			if hookState.position == nil then
				local initialSource = value
				if initialSource == nil then
					initialSource = goal
				end
				if initialSource == nil then
					initialSource = CFrame.new()
				end
				hookState.position = initialSource
				hookState.lastAtClock = os.clock()

				if duration ~= nil and goal ~= nil then
					local distance = (goal.Position - hookState.position.Position).Magnitude
					if duration <= 0 then
						hookState.position = goal
						hookState.speed = 0
					else
						hookState.speed = distance / duration
					end
					hookState.speedLockedFromDuration = true
				else
					hookState.speed = if speed ~= nil then speed else 1
				end
			end

			if speed ~= nil and not hookState.speedLockedFromDuration then
				hookState.speed = speed
			end

			local now = os.clock()
			local dt = now - hookState.lastAtClock
			hookState.lastAtClock = now

			if goal ~= nil then
				local current = hookState.position
				local distance = (goal.Position - current.Position).Magnitude

				if distance <= LINEAR_WALK_EPSILON or hookState.speed * dt >= distance then
					hookState.position = goal
				elseif dt > 0 and hookState.speed ~= 0 then
					local maxStep = hookState.speed * dt
					hookState.position = current:Lerp(goal, math.clamp(maxStep / distance, 0, 1))
				end
			end

			return hookState.position
		end

		if hookState.linearWalkIsColor3 == nil then
			hookState.linearWalkIsColor3 = JecsImmediateHookUtils.usesColor3(goal, value)
		end
		local isColor3 = hookState.linearWalkIsColor3

		if hookState.position == nil then
			local initialSource = value
			if initialSource == nil then
				initialSource = goal
			end
			if initialSource == nil then
				initialSource = if isColor3 then Vector3.zero else 0
			end
			hookState.position = JecsImmediateHookUtils.internalValue(initialSource)
			hookState.lastAtClock = os.clock()

			if duration ~= nil and goal ~= nil then
				local target = JecsImmediateHookUtils.internalValue(goal)
				local delta = target - hookState.position
				local distance = if typeof(delta) == "number" then math.abs(delta) else delta.Magnitude
				if duration <= 0 then
					hookState.position = target
					hookState.speed = 0
				else
					hookState.speed = distance / duration
				end
				hookState.speedLockedFromDuration = true
			else
				hookState.speed = if speed ~= nil then speed else 1
			end
		end

		if speed ~= nil and not hookState.speedLockedFromDuration then
			hookState.speed = speed
		end

		local now = os.clock()
		local dt = now - hookState.lastAtClock
		hookState.lastAtClock = now

		if goal ~= nil then
			local target = JecsImmediateHookUtils.internalValue(goal)
			local current = hookState.position
			local delta = target - current
			local distance = if typeof(delta) == "number" then math.abs(delta) else delta.Magnitude

			if distance <= LINEAR_WALK_EPSILON or hookState.speed * dt >= distance then
				hookState.position = target
			elseif dt > 0 and hookState.speed ~= 0 then
				local maxStep = hookState.speed * dt
				if typeof(delta) == "number" then
					hookState.position = current + (if delta > 0 then maxStep else -maxStep)
				else
					hookState.position = current + delta.Unit * maxStep
				end
			end
		end

		return JecsImmediateHookUtils.externalValue(hookState.position, isColor3)
	end
end
