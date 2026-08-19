--!nonstrict
--[=[
	@class JecsImmediateHooksCommonHooks

	Built-in immediate-mode hooks. Each pack is `(runtime) -> { name = fn }`;
	functions close over `runtime` so call sites are `hooks.gate()` etc.

	`dis` is always the first optional argument, after every required argument.
]=]
local require = require(script.Parent.loader).load(script)

local Jecs = require("Jecs")
local JecsImmediateHookUtils = require("JecsImmediateHookUtils")
local JecsImmediateUtils = require("JecsImmediateUtils")
local Jecst = require("Jecst")
local Maid = require("Maid")
local Observable = require("Observable")
local RandomUtils = require("RandomUtils")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local Signal = require("Signal")
local Spring = require("Spring")
local TieRealms = require("TieRealms")
local ValueObject = require("ValueObject")

local getOrCreateHookState = JecsImmediateHookUtils.getOrCreateHookState

local LINEAR_WALK_EPSILON = 1e-4

local function usesCFrame(goal: any?, value: any?): boolean
	if goal ~= nil then
		return typeof(goal) == "CFrame"
	end
	if value ~= nil then
		return typeof(value) == "CFrame"
	end
	return false
end

type ThrottledSetQueueInput = { any } | Jecst.Query<any> | Jecst.Cached_Query<any>

local function forEachIdentity(input: ThrottledSetQueueInput?, onIdentity: (any) -> ())
	if typeof(input) ~= "table" then
		return
	end

	local mt = getmetatable(input :: any)
	if typeof(mt) == "table" and mt.__iter ~= nil then
		for identity in input :: Jecst.Query<any> do
			if identity ~= nil then
				onIdentity(identity)
			end
		end
		return
	end

	for _, identity in input :: { any } do
		if identity ~= nil then
			onIdentity(identity)
		end
	end
end

export type SchedulerState = {
	lastCalledAt: number,
	currentOverallTime: number,
	currentStageTime: number,
	currentStageDuration: number?,
	currentStageAlpha: number,
	currentCallback: (() -> ...any) | nil,
	currentTimeKey: number | nil,
	isHeld: boolean,
	hold: boolean,
}

return function(runtime: JecsImmediateHookUtils.ImmediateRuntime_Jecs_HookBook<any>)
	return {
		async = function(asyncFunction: ({ any }, Maid.Maid) -> any, dis: any?)
			type AsyncHookState = {
				_startedAsync: boolean?,
				_ret: { any },
			}
			local hookState: AsyncHookState, hookMaid = getOrCreateHookState(runtime, dis)

			if hookState._startedAsync == nil then
				hookState._startedAsync = true
				hookState._ret = {}
				hookMaid:GiveTask(task.spawn(function()
					asyncFunction(hookState._ret, hookMaid)
				end))
			end
			return hookState._ret
		end,

		cache = function(
			cacheFunction: (maid: Maid.Maid) -> any,
			dis: any?,
			cleanup: ((value: any) -> any)?,
			debug: boolean?
		)
			type CacheHookState = {
				cachedValue: { any },
				cleanup: ((value: any) -> any)?,
			}
			if debug then
				print(`cache: called with dis {dis}`)
			end
			local hookState: CacheHookState, hookMaid = getOrCreateHookState(runtime, dis)
			if hookState.cachedValue == nil then
				hookState.cachedValue = table.pack(cacheFunction(hookMaid))
				hookState.cleanup = cleanup
				local cachedValue = hookState.cachedValue

				hookMaid:GiveTask(function()
					if cachedValue == nil then
						return
					end
					if cleanup then
						cleanup(table.unpack(cachedValue))
					end
				end)
			end
			return table.unpack(hookState.cachedValue)
		end,

		changed = function(value: any, dis: any?, runFirst: boolean?, onlyOnEqualTo: any?)
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis)

			if hookState.lastValue == nil then
				hookState.lastValue = value
				if onlyOnEqualTo ~= nil then
					return value == onlyOnEqualTo
				end
				if runFirst == true then
					return true
				end
				return false
			end

			if hookState.lastValue ~= value then
				hookState.lastValue = value
				if onlyOnEqualTo ~= nil then
					return value == onlyOnEqualTo
				else
					return true
				end
			end

			return false
		end,

		conditionSustained = function(condition: boolean, dis: any?)
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis)

			if not condition then
				hookState.lastSatisfiedClock = nil
				return 0
			end

			local now = os.clock()
			if not hookState.lastSatisfiedClock then
				hookState.lastSatisfiedClock = now
				return 0
			end

			return now - hookState.lastSatisfiedClock
		end,

		counter = function(dis: any?)
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis)
			hookState.counter = (hookState.counter or 0) + 1
			return hookState.counter
		end,

		delayed = function(seconds: number, dis: any?)
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis)

			local now = os.clock()

			if hookState.lastRanAtClock == nil then
				hookState.lastRanAtClock = now
				return false
			end

			if now - hookState.lastRanAtClock >= seconds then
				hookState.lastRanAtClock = now
				return true
			end

			return false
		end,

		delta = function(
			value: JecsImmediateHookUtils.AverageableValue,
			dis: any?,
			conditionToEvaluate: boolean?
		): JecsImmediateHookUtils.AverageableValue
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis)

			if conditionToEvaluate == false then
				if hookState.lastValue then
					return value - hookState.lastValue
				else
					return JecsImmediateHookUtils.zeroSum(value)
				end
			end

			local lastValue = hookState.lastValue
			hookState.lastValue = value
			if lastValue == nil then
				return JecsImmediateHookUtils.zeroSum(value)
			end
			return (value :: any) - lastValue, lastValue
		end,

		deltatime = function(dis: any?, flagToUpdate: boolean?)
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis)

			local now = os.clock()
			local lastAtClock = hookState.lastAtClock
			if lastAtClock == nil then
				hookState.lastAtClock = now
				return 0
			end

			local delta = now - lastAtClock

			if flagToUpdate == nil or flagToUpdate == true then
				hookState.lastAtClock = now
			end

			return delta
		end,

		difference = function(currentNumber: number, dis: any?, flagToUpdate: boolean?)
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis)

			if hookState.lastNumber == nil then
				hookState.lastNumber = currentNumber
				return 0
			end

			local difference = currentNumber - hookState.lastNumber

			if flagToUpdate == nil or flagToUpdate == true then
				hookState.lastNumber = currentNumber
			end

			return difference
		end,

		draw = function(drawnThing: any, dis: any?)
			local _hookState, _hookMaid = getOrCreateHookState(runtime, dis)
			_hookMaid._currentlyDrawnThing = drawnThing
			return drawnThing
		end,

		entity = function(entity: Jecst.Entity)
			return { __hookentity = entity }
		end,

		filterDescendants = function(
			instanceArg: Instance | { Instance },
			filterFunction: (Instance) -> boolean,
			dis: any?
		): { Instance }
			local hookState, hookMaid = getOrCreateHookState(runtime, dis)
			assert(instanceArg, "instanceArg is nil")
			assert(
				typeof(instanceArg) == "Instance" or typeof(instanceArg) == "table",
				"instanceArg must be an Instance or a table of Instances"
			)

			if not hookState.instances then
				hookState.instances = if typeof(instanceArg) == "table"
					then table.clone(instanceArg)
					else { instanceArg }
				for _, instance in hookState.instances do
					assert(instance, "instance is nil")
					assert(instance:IsA("Instance"), "instance must be an Instance")
				end
			end

			if hookState.filteredDescendants == nil then
				local list: { Instance } = {}
				hookState.filteredDescendants = list
				for _, instance in hookState.instances do
					hookMaid:GiveTask(
						RxInstanceUtils.observeDescendantsBrio(instance, filterFunction)
							:Subscribe(function(descendantBrio)
								if descendantBrio:IsDead() then
									return
								end

								local maid, descendant = descendantBrio:ToMaidAndValue()
								table.insert(list, descendant)
								maid:GiveTask(function()
									local index = table.find(list, descendant)
									if index then
										local last = #list
										list[index] = list[last]
										list[last] = nil
									end
								end)
							end)
					)
				end
			end
			return hookState.filteredDescendants
		end,

		findChild = function(parentInstance: Instance, name: string, dis: any?, recursive: boolean?)
			if not parentInstance then
				error(`parentInstance is nil: {dis} {name} {recursive}`)
			end
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis)
			if hookState._init == nil then
				hookState._init = true
				hookState._startedAt = os.clock()
				hookState._warnedAt = os.clock()
				hookState.foundChild = nil
			end
			if hookState.foundChild == nil then
				hookState.foundChild = parentInstance:FindFirstChild(name, recursive)
			end
			if
				hookState.foundChild == nil
				and os.clock() - hookState._startedAt > 5
				and os.clock() - hookState._warnedAt > 5
			then
				hookState._warnedAt = os.clock()
				warn(`findFirstChild: not finding {name} in {parentInstance:GetFullName()} after 5 seconds...`)
			end
			return hookState.foundChild
		end,

		gate = function(dis: any?): boolean
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis)
			if hookState.ran then
				return false
			end
			hookState.ran = true
			return true
		end,

		gatecounter = function(dis: any?)
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis, function(state)
				if state._activeThisFrame then
					state._onHotPath = true
					state._activeThisFrame = nil
				elseif state._onHotPath then
					state.counter = (state.counter or 1) + 1
					state._onHotPath = false
				end
				return false
			end)
			if hookState.counter == nil then
				hookState.counter = 1
			end
			hookState._activeThisFrame = true
			return hookState.counter
		end,

		hookEntity = function(dis: any?, initDecorator: ((Jecst.Entity) -> any?)?)
			local hookState, _hookMaid, hookStateEntity = getOrCreateHookState(runtime, dis)
			if not hookState.childEntity then
				hookState.childEntity = runtime.world:entity()
				runtime.world:add(hookState.childEntity, Jecs.pair(runtime.comps.ChildOf, hookStateEntity))
				if initDecorator then
					initDecorator(hookState.childEntity)
				end
			end
			return hookState.childEntity
		end,

		linearWalk = function(dis: any?, goal: any?, value: any?, speed: number?, duration: number?): any
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis)

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
		end,

		maid = function(dis: any?, callback: ((maid: Maid.Maid) -> any?)?)
			local _hookState, hookMaid = getOrCreateHookState(runtime, dis, function(_state)
				if callback then
					callback(_state.hookMaid)
				end
				return true
			end)
			if not _hookState.hookMaid then
				_hookState.hookMaid = hookMaid
			end
			return hookMaid
		end,

		noise = function(dis: any?, min: number?, max: number?, frequency: number?): number
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis)

			local lo = if min ~= nil then min else 0
			local hi = if max ~= nil then max else 1
			local freq = if frequency ~= nil then frequency else 1

			local now = os.clock()
			if not hookState.noiseInit then
				hookState.noiseInit = true
				hookState.noisePhase = 0
				hookState.noiseLastClock = now
				local rng = Random.new()
				hookState.noiseOy = rng:NextNumber(0.1, 1000)
				hookState.noiseOz = rng:NextNumber(0.1, 1000)
				hookState.noiseOx = rng:NextNumber(0.1, 1000)
			end

			local dt = now - hookState.noiseLastClock
			hookState.noiseLastClock = now
			hookState.noisePhase += math.max(dt, 0) * freq

			local n = math.noise(hookState.noisePhase + hookState.noiseOx, hookState.noiseOy, hookState.noiseOz)
			local u = math.clamp(n + 0.5, 0, 1)
			return lo + (hi - lo) * u
		end,

		random = function(dis: any?, min: number?, max: number?, seed: number?)
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis)
			if hookState.randomNumber == nil then
				local rng = Random.new(seed)
				hookState.randomNumber = rng:NextNumber(min or 0, max or 1)
			end
			return hookState.randomNumber
		end,

		randomChoice = function(
			choices: { [any]: number },
			dis: any?,
			alwaysRandom: boolean?,
			noCache: boolean?,
			rng: Random?
		)
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis)
			if not hookState.init then
				hookState.init = true
				hookState.arrayOfValues = {}
				hookState.arrayOfWeights = {}
				for value, weight in choices do
					table.insert(hookState.arrayOfValues, value)
					table.insert(hookState.arrayOfWeights, weight)
				end
				hookState.chosen = RandomUtils.weightedChoice(hookState.arrayOfValues, hookState.arrayOfWeights, rng)
				_hookMaid:GiveTask(function()
					table.clear(hookState)
				end)
			end
			if noCache then
				if alwaysRandom == true then
					hookState.arrayOfValues = {}
					hookState.arrayOfWeights = {}
					for value, weight in choices do
						table.insert(hookState.arrayOfValues, value)
						table.insert(hookState.arrayOfWeights, weight)
					end
					hookState.chosen =
						RandomUtils.weightedChoice(hookState.arrayOfValues, hookState.arrayOfWeights, rng)
				end
			else
				if alwaysRandom == true then
					hookState.chosen =
						RandomUtils.weightedChoice(hookState.arrayOfValues, hookState.arrayOfWeights, rng)
				end
			end
			return hookState.chosen
		end,

		rtbuffer = function(dis: any?)
			local hookState, hookMaid = getOrCreateHookState(runtime, dis, nil, true)
			hookState.calledThisFrame = true
			if hookState.tab == nil then
				hookState.tab = {}
			end
			return hookState.tab, hookMaid
		end,

		scheduledValues = function(
			phases: {
				[number]: any,
			},
			dis: any?,
			forceInOrder: boolean?
		): {
			lastCalledAt: number,
			currentOverallTime: number,
			currentStageTime: number,
			currentStageDuration: number?,
			currentStageAlpha: number,
			currentValue: any,
			currentTimeKey: number | nil,
		}
			local _hookState, _hookMaid = getOrCreateHookState(runtime, dis)
			local currClock = os.clock()

			if not _hookState._init then
				_hookState._init = true
				_hookState._timekeyToValue = phases
				_hookState._sortedTimeKeys = {}
				_hookState._timeKeysVisited = {}
				_hookState.lastCalledAt = currClock
				_hookState.currentOverallTime = 0
				_hookState.currentStageTime = 0
				_hookState.currentStageDuration = nil
				_hookState.currentStageAlpha = 0
				_hookState.currentValue = nil
				_hookState.currentTimeKey = nil

				for timestamp, _value in phases do
					table.insert(_hookState._sortedTimeKeys, timestamp)
					_hookState._timeKeysVisited[timestamp] = false
				end
				table.sort(_hookState._sortedTimeKeys)

				_hookMaid:GiveTask(function()
					table.clear(_hookState)
				end)

				_hookState.evaluateCurrentTimeKey = function()
					for i, timeKey in _hookState._sortedTimeKeys do
						if _hookState._forceInOrder then
							local weArePastIt = _hookState.currentOverallTime >= timeKey
							local weHaventExecutedBefore = not _hookState._timeKeysVisited[timeKey]
							if weArePastIt and weHaventExecutedBefore then
								return timeKey
							end
						end
						if _hookState.currentOverallTime < timeKey then
							local prevTimeKey = _hookState._sortedTimeKeys[i - 1]
							if prevTimeKey then
								return prevTimeKey
							else
								return nil
							end
						end
					end
					return _hookState._sortedTimeKeys[#_hookState._sortedTimeKeys]
				end
				_hookState.evaluateAndReturnValue = function()
					local timeKey = _hookState.evaluateCurrentTimeKey()
					if timeKey then
						if _hookState.currentTimeKey ~= timeKey then
							_hookState.currentStageTime = 0
						end
						_hookState.currentTimeKey = timeKey
						local value = _hookState._timekeyToValue[timeKey]
						_hookState.currentValue = value
						_hookState._timeKeysVisited[timeKey] = true
						return value
					end
					return nil
				end
				_hookState.evaluateCurrentStageDuration = function()
					local currentTimeKey = _hookState.currentTimeKey
					if currentTimeKey == nil then
						return nil
					end

					local sortedTimeKeys = _hookState._sortedTimeKeys
					local currentIndex = table.find(sortedTimeKeys, currentTimeKey)
					local nextTimeKey = currentIndex and sortedTimeKeys[currentIndex + 1]
					if nextTimeKey == nil then
						return nil
					end

					local duration = nextTimeKey - currentTimeKey
					if duration <= 0 then
						return nil
					end

					return duration
				end
			end

			_hookState._forceInOrder = forceInOrder == true

			local timeSinceLastCall = currClock - _hookState.lastCalledAt
			_hookState.currentOverallTime += timeSinceLastCall
			_hookState.currentStageTime += timeSinceLastCall
			_hookState.lastCalledAt = currClock
			_hookState.evaluateAndReturnValue()
			if _hookState.currentTimeKey ~= nil then
				_hookState.currentStageTime = math.max(_hookState.currentOverallTime - _hookState.currentTimeKey, 0)
			end
			_hookState.currentStageDuration = _hookState.evaluateCurrentStageDuration()
			if _hookState.currentStageDuration then
				_hookState.currentStageAlpha =
					math.clamp(_hookState.currentStageTime / _hookState.currentStageDuration, 0, 1)
			else
				_hookState.currentStageAlpha = if _hookState.currentTimeKey == nil then 0 else 1
			end

			return {
				lastCalledAt = _hookState.lastCalledAt,
				currentOverallTime = _hookState.currentOverallTime,
				currentStageTime = _hookState.currentStageTime,
				currentStageDuration = _hookState.currentStageDuration,
				currentStageAlpha = _hookState.currentStageAlpha,
				currentValue = _hookState.currentValue,
				currentTimeKey = _hookState.currentTimeKey,
			}
		end,

		scheduler = function(
			phases: {
				[number]: ((SchedulerState) -> ...any) | nil,
			},
			dis: any?,
			forceInOrder: boolean?
		): {
			lastCalledAt: number,
			currentOverallTime: number,
			currentStageTime: number,
			currentStageDuration: number?,
			currentStageAlpha: number,
			currentCallback: (() -> ...any) | nil,
			currentTimeKey: number | nil,
			isHeld: boolean,
		}
			local _hookState, _hookMaid = getOrCreateHookState(runtime, dis)
			local currClock = os.clock()

			if not _hookState._init then
				_hookState._init = true
				_hookState._sortedTimeKeys = {}
				_hookState._timeKeysVisited = {}
				_hookState._heldTimeKey = nil
				_hookState.lastCalledAt = currClock
				_hookState.currentOverallTime = 0
				_hookState.currentStageTime = 0
				_hookState.currentStageDuration = nil
				_hookState.currentStageAlpha = 0
				_hookState.currentCallback = nil
				_hookState.currentTimeKey = nil
				_hookState.hold = false

				for timestamp, _callback in phases do
					table.insert(_hookState._sortedTimeKeys, timestamp)
					_hookState._timeKeysVisited[timestamp] = false
				end
				table.sort(_hookState._sortedTimeKeys)

				_hookMaid:GiveTask(function()
					table.clear(_hookState)
				end)
				_hookState.evaluateCurrentTimeKey = function()
					if _hookState._heldTimeKey ~= nil then
						return _hookState._heldTimeKey
					end
					for i, timeKey in _hookState._sortedTimeKeys do
						if _hookState._forceInOrder then
							local weArePastIt = _hookState.currentOverallTime >= timeKey
							local weHaventExecutedBefore = not _hookState._timeKeysVisited[timeKey]
							if weArePastIt and weHaventExecutedBefore then
								return timeKey
							end
						end
						if _hookState.currentOverallTime < timeKey then
							local prevTimeKey = _hookState._sortedTimeKeys[i - 1]
							if prevTimeKey then
								return prevTimeKey
							else
								return nil
							end
						end
					end
					return _hookState._sortedTimeKeys[#_hookState._sortedTimeKeys]
				end
				_hookState.evaluateCurrentStageDuration = function()
					local currentTimeKey = _hookState.currentTimeKey
					if currentTimeKey == nil then
						return nil
					end

					local sortedTimeKeys = _hookState._sortedTimeKeys
					local currentIndex = table.find(sortedTimeKeys, currentTimeKey)
					local nextTimeKey = currentIndex and sortedTimeKeys[currentIndex + 1]
					if nextTimeKey == nil then
						return nil
					end

					local duration = nextTimeKey - currentTimeKey
					if duration <= 0 then
						return nil
					end

					return duration
				end
			end

			_hookState._forceInOrder = forceInOrder == true

			local timeSinceLastCall = currClock - _hookState.lastCalledAt
			_hookState.currentOverallTime += timeSinceLastCall
			_hookState.currentStageTime += timeSinceLastCall
			_hookState.lastCalledAt = currClock
			local timeKey = _hookState.evaluateCurrentTimeKey()
			if timeKey then
				if _hookState.currentTimeKey ~= timeKey then
					_hookState.currentStageTime = 0
				end
				_hookState.currentTimeKey = timeKey
				_hookState.currentStageDuration = _hookState.evaluateCurrentStageDuration()
				if _hookState.currentStageDuration then
					_hookState.currentStageAlpha =
						math.clamp(_hookState.currentStageTime / _hookState.currentStageDuration, 0, 1)
				else
					_hookState.currentStageAlpha = 1
				end
				local callback = phases[timeKey]
				_hookState.currentCallback = callback
				_hookState._timeKeysVisited[timeKey] = true
				if callback then
					_hookState.hold = false
					local result: any = callback(_hookState)
					if result == false or _hookState.hold then
						_hookState._heldTimeKey = timeKey
					else
						_hookState._heldTimeKey = nil
					end
				else
					_hookState._heldTimeKey = nil
				end
			else
				_hookState.currentStageDuration = nil
				_hookState.currentStageAlpha = 0
				_hookState._heldTimeKey = nil
			end

			return {
				lastCalledAt = _hookState.lastCalledAt,
				currentOverallTime = _hookState.currentOverallTime,
				currentStageTime = _hookState.currentStageTime,
				currentStageDuration = _hookState.currentStageDuration,
				currentStageAlpha = _hookState.currentStageAlpha,
				currentCallback = _hookState.currentCallback,
				currentTimeKey = _hookState.currentTimeKey,
				isHeld = _hookState._heldTimeKey ~= nil,
			}
		end,

		sin = function(dis: any?, min: number?, max: number?, frequency: number?, startPhase: number?): number
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis)

			local lo = if min ~= nil then min else 0
			local hi = if max ~= nil then max else 1
			local freq = if frequency ~= nil then frequency else 1

			local now = os.clock() + (startPhase or 0)
			if not hookState.sinInit then
				hookState.sinInit = true
				hookState.sinPhase = Random.new():NextNumber(0, 1)
				hookState.sinLastClock = now
			end

			local dt = now - hookState.sinLastClock
			hookState.sinLastClock = now
			hookState.sinPhase += math.max(dt, 0) * freq

			local u = (math.sin(hookState.sinPhase * math.pi * 2) + 1) * 0.5
			return lo + (hi - lo) * u
		end,

		slidingAvg = function(
			value: JecsImmediateHookUtils.AverageableValue,
			windowSize: number,
			dis: any?,
			conditionToInclude: boolean?,
			fillBufferWithFirstValue: boolean?
		)
			assert(windowSize >= 1, "slidingAvg windowSize must be >= 1")

			local hookState, _hookMaid = getOrCreateHookState(runtime, dis)
			if not hookState.init then
				hookState.init = true
				hookState.windowSize = windowSize
				hookState.buffer = table.create(windowSize)
				hookState.head = 1
				hookState.count = 0
				hookState.sum = JecsImmediateHookUtils.zeroSum(value)
				hookState.zeroSum = hookState.sum
				hookState.push = function(pushValue: JecsImmediateHookUtils.AverageableValue)
					local capacity = hookState.windowSize
					local i = hookState.head
					local old = hookState.buffer[i]
					hookState.buffer[i] = pushValue
					hookState.head = (i % capacity) + 1
					if hookState.count < capacity then
						hookState.count += 1
						hookState.sum += pushValue
					else
						hookState.sum += pushValue - old
					end
				end
				hookState.clear = function()
					table.clear(hookState.buffer)
					hookState.head = 1
					hookState.count = 0
					hookState.sum = hookState.zeroSum
				end
				if fillBufferWithFirstValue then
					for _ = 1, windowSize do
						hookState.push(value)
					end
				end
			end

			if conditionToInclude ~= nil then
				if conditionToInclude == true then
					hookState.push(value)
				end
			else
				hookState.push(value)
			end

			return JecsImmediateHookUtils.quotient(hookState.sum, hookState.count), hookState.push, hookState.clear
		end,

		spring = function(
			dis: any?,
			goal: any?,
			value: any?,
			speed: number?,
			damping: number?
		): (any, Spring.Spring<any>?)
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis)

			if hookState.springIsCFrame == nil then
				hookState.springIsCFrame = usesCFrame(goal, value)
			end

			if hookState.springIsCFrame then
				if not hookState.springPos then
					local finalStartCF = value
					if not finalStartCF then
						finalStartCF = goal
					end
					if not finalStartCF then
						finalStartCF = CFrame.new()
					end
					hookState.springPos = Spring.new(finalStartCF.Position)
					hookState.springPos.Position = finalStartCF.Position
					hookState.springPos.Speed = speed or 10
					hookState.springPos.Damper = damping or 1
					hookState.springLookAlong = Spring.new(finalStartCF.LookVector)
					hookState.springLookAlong.Position = finalStartCF.LookVector
					hookState.springLookAlong.Speed = speed or 10
					hookState.springLookAlong.Damper = damping or 1
					hookState.springUpVector = Spring.new(finalStartCF.UpVector)
					hookState.springUpVector.Position = finalStartCF.UpVector
					hookState.springUpVector.Speed = speed or 10
					hookState.springUpVector.Damper = damping or 1
				end

				if speed then
					hookState.springPos.Speed = speed
					hookState.springLookAlong.Speed = speed
					hookState.springUpVector.Speed = speed
				end
				if damping then
					hookState.springPos.Damper = damping
					hookState.springLookAlong.Damper = damping
					hookState.springUpVector.Damper = damping
				end

				if goal ~= nil then
					hookState.springPos.Target = goal.Position
					hookState.springLookAlong.Target = goal.LookVector
					hookState.springUpVector.Target = goal.UpVector
				end

				hookState.finalCFrame = CFrame.lookAlong(
					hookState.springPos.Position,
					hookState.springLookAlong.Position,
					hookState.springUpVector.Position
				)
				return hookState.finalCFrame, nil
			end

			if hookState.springIsColor3 == nil then
				hookState.springIsColor3 = JecsImmediateHookUtils.usesColor3(goal, value)
			end
			local isColor3 = hookState.springIsColor3

			if not hookState.spring then
				local initialSource = value
				if initialSource == nil then
					initialSource = goal
				end
				if initialSource == nil then
					initialSource = if isColor3 then Vector3.zero else 0
				end
				local initial = JecsImmediateHookUtils.internalValue(initialSource)
				hookState.spring = Spring.new(initial)
				hookState.spring.Speed = speed or 10
				hookState.spring.Damper = damping or 1
				hookState.spring.Position = initial
			end

			if speed then
				hookState.spring.Speed = speed
			end
			if damping then
				hookState.spring.Damper = damping
			end

			if goal ~= nil then
				hookState.spring.Target = JecsImmediateHookUtils.internalValue(goal)
			end

			local position = JecsImmediateHookUtils.externalValue(hookState.spring.Position, isColor3)
			return position, hookState.spring
		end,

		state = function(dis: any?, initFunction: ({ any? }, Maid.Maid) -> ...any?)
			local hookState, hookMaid = getOrCreateHookState(runtime, dis)
			if hookState._init == nil then
				hookState._init = true
				if initFunction then
					initFunction(hookState, hookMaid)
				end
			end
			return hookState, hookMaid
		end,

		subscribe = function(
			subscribable: Observable.Observable<any> | Signal.Signal<any>,
			dis: any?,
			returnLastEmittedOnly: boolean?
		)
			local function toObservable(
				source: Observable.Observable<any> | Signal.Signal<any>
			): Observable.Observable<any>
				if typeof(source) == "RBXScriptSignal" or Signal.isSignal(source) then
					return Rx.fromSignal(source :: Signal.Signal<any>)
				end
				if Observable.isObservable(source) then
					return source :: Observable.Observable<any>
				end
				return Rx.fromSignal(source :: Signal.Signal<any>)
			end

			local hookState, hookMaid = getOrCreateHookState(runtime, dis)

			if hookState.collector == nil then
				hookState.collector =
					hookMaid:Add(JecsImmediateUtils.collectObservable(toObservable(subscribable), hookMaid))
			end

			local collector = hookState.collector
			assert(collector, "subscribe hook collector missing")

			if returnLastEmittedOnly then
				return collector.Last()
			end
			return collector.Drain()
		end,

		throttle = function(seconds: number, dis: any?, delayOnFirstCall: boolean?)
			local hookState, _hookMaid = getOrCreateHookState(runtime, dis, function(_state)
				return _state.lastRanAtClock == nil or (os.clock() - _state.lastRanAtClock) >= (_state.seconds or 0)
			end)
			hookState.seconds = seconds

			local now = os.clock()
			local lastRanAtClock = hookState.lastRanAtClock

			if lastRanAtClock == nil then
				hookState.lastRanAtClock = now
				return not delayOnFirstCall
			end

			if now - lastRanAtClock >= seconds then
				hookState.lastRanAtClock = now
				return true
			end

			return false
		end,

		throttledSetQueue = function(
			input: ThrottledSetQueueInput,
			dis: any?,
			maxCount: number?,
			maxTime: number?
		): () -> any?
			debug.profilebegin("throttledSetQueue")
			local hookState, hookMaid = getOrCreateHookState(runtime, dis)

			if hookState.queue == nil then
				hookState.queue = {}
				hookState.inQueue = {}
				hookMaid:GiveTask(function()
					table.clear(hookState)
				end)
			end

			debug.profilebegin("throttledSetQueue.forEachIdentity")
			local seen = {}
			forEachIdentity(input, function(identity)
				seen[identity] = true
				if not hookState.inQueue[identity] then
					hookState.inQueue[identity] = true
					table.insert(hookState.queue, identity)
				end
			end)
			debug.profileend()

			debug.profilebegin("throttledSetQueue.kept")
			local kept = {}
			for _, identity in hookState.queue do
				if seen[identity] then
					table.insert(kept, identity)
				else
					hookState.inQueue[identity] = nil
				end
			end
			hookState.queue = kept
			debug.profileend()

			debug.profilebegin("throttledSetQueue.countBudget")
			-- Default to one identity when neither bound is set.
			local countBudget = maxCount
			if countBudget == nil and maxTime == nil then
				countBudget = 1
			end
			debug.profileend()

			local emittedCount = 0
			local startedAt: number? = nil
			debug.profileend()
			return function()
				debug.profilebegin("throttledSetQueue.returnedcallback")
				local origin = startedAt
				if origin == nil then
					origin = os.clock()
					startedAt = origin
				end
				if countBudget ~= nil and emittedCount >= countBudget then
					return nil
				end
				if maxTime ~= nil and (os.clock() - origin) >= maxTime then
					return nil
				end
				if #hookState.queue == 0 then
					return nil
				end

				debug.profilebegin("throttledSetQueue.returnedcallback.remove")
				local identity = table.remove(hookState.queue, 1)
				hookState.inQueue[identity] = nil
				emittedCount += 1
				debug.profileend()

				debug.profilebegin("throttledSetQueue.returnedcallback.add")
				if seen[identity] and not hookState.inQueue[identity] then
					hookState.inQueue[identity] = true
					table.insert(hookState.queue, identity)
				end
				debug.profileend()

				debug.profileend()
				return identity
			end
		end,

		tween = function(_start: any, _goal: any, _duration: number, _dis: any?) end,

		value = function(initialValue: any, dis: any?): ValueObject.ValueObject<any>
			local hookState, hookMaid = getOrCreateHookState(runtime, dis)
			if hookState.valueObject == nil then
				hookState.valueObject = hookMaid:Add(ValueObject.new(initialValue))
			end
			return hookState.valueObject
		end,

		useBinder = function(instance: Instance, binderTag: string, dis: any?, debug: boolean?)
			local hookState, hookMaid = getOrCreateHookState(runtime, dis)

			if hookState.boundObject ~= nil then
				return hookState.boundObject
			end

			if hookState.pendingPromise ~= nil then
				if debug then
					warn(`Pending promise for {binderTag} exists...`)
				end
				return nil
			end

			local binder = runtime.serviceBag:GetService(runtime.require(binderTag))
			if not binder then
				warn(`No binder found for tag {binderTag}`)
				return nil
			end

			if not hookState.startedBinderPromise then
				if debug then
					warn(`Starting promise for {binderTag}`)
				end
				hookState.startedBinderPromise = true
				hookMaid:GivePromise(binder
					:Promise(instance)
					:Then(function(boundObject)
						if debug then
							warn(`Bound object for {binderTag}!`)
						end
						hookState.boundObject = boundObject
					end)
					:Catch(function(err)
						warn(`Failed to start binder promise for {binderTag}`, err)
						hookState.boundObject = nil
					end))
				return binder:Get(instance)
			end

			return nil
		end,

		useTieInterface = function(instance: Instance, tieInterfaceName: string, dis: any?, realm: TieRealms.TieRealm?)
			local hookState, hookMaid = getOrCreateHookState(runtime, dis)
			if hookState.observingBrio == nil then
				local tieInterface = runtime.require(tieInterfaceName)
				if realm then
					tieInterface = tieInterface[realm]
				end
				hookState.observingBrio = hookMaid:GiveTask(tieInterface:ObserveBrio(instance):Subscribe(function(brio)
					if brio:IsDead() then
						hookState.currentInterface = nil
						return
					end
					local _maid, interface = brio:ToMaidAndValue()
					hookState.currentInterface = interface
				end))
			end
			return hookState.currentInterface
		end,
	}
end
