--!nonstrict
--[=[
	@class scheduledValues
]=]

local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local getOrCreateHookState = require("ImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(
		phases: {
			[number]: any,
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
		currentValue: any,
		currentTimeKey: number | nil,
	}
		local _hookState, _hookMaid = getOrCreateHookState(rt, dis)
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
	end
end
