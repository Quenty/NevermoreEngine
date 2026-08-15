--!nonstrict
--[=[
	@class scheduler

	When called, will progress a timeline.
	Will call provided callbacks based on defined timestamps every time this is called
	(meant to be a per-tick basis).
	Callbacks the one that is last timestamp before it.
	Each callback is called with the current overall time elapsed since init,
	and time elapsed in current stage.
	Returns current overall time.

	Set stage.hold = true from a callback to hold (pin) that stage. The scheduler
	keeps invoking it every tick and will not advance until a tick where hold is
	not requested. Returning false also holds at runtime, but stage.hold avoids
	Luau unifying mixed callback return types in a numeric table literal.
	The clock keeps running while held; absolute key times may drift. Prefer
	forceInOrder when holds may overrun later keys so unvisited stages catch up.

	phases: {
		[0] = init()
		[0.1] = something()
		[1.0] = something()
		[2.0] = cleanupfunc()
	}

	Returns scheduler state.
]=]

local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local getOrCreateHookState = require("ImmediateHookUtils").getOrCreateHookState

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

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(
		phases: {
			[number]: ((SchedulerState) -> ...any) | nil,
		},
		dis: any?,
		-- forceInOrder: if true, will force the scheduler
		-- to call callbacks in order of time keys even if
		-- current time already elapsed (will call in a sequence at least once.)
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
		local _hookState, _hookMaid = getOrCreateHookState(rt, dis)
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
				-- From earliest to latest
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
				-- If we've gone through all the time keys and didn't find one,
				-- return the last time key since we're past all of them.
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
	end
end
