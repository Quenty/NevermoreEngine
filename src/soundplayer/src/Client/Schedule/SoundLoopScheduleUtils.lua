--[=[
	@class SoundLoopScheduleUtils
]=]

local require = require(script.Parent.loader).load(script)

local NumberRangeUtils = require("NumberRangeUtils")
local Table = require("Table")
local t = require("t")

local SoundLoopScheduleUtils = {}

function SoundLoopScheduleUtils.schedule(loopedSchedule: SoundLoopSchedule): SoundLoopSchedule
	assert(SoundLoopScheduleUtils.isLoopedSchedule(loopedSchedule))

	return table.freeze(loopedSchedule)
end

function SoundLoopScheduleUtils.onNextLoop(loopedSchedule: SoundLoopSchedule): SoundLoopSchedule
	assert(SoundLoopScheduleUtils.isLoopedSchedule(loopedSchedule) or loopedSchedule == nil, "Bad loopedSchedule")

	loopedSchedule = loopedSchedule or {}
	return SoundLoopScheduleUtils.schedule(Table.merge(loopedSchedule, {
		playOnNextLoop = true,
	}))
end

function SoundLoopScheduleUtils.maxLoops(maxLoops: number, loopedSchedule: SoundLoopSchedule): SoundLoopSchedule
	assert(type(maxLoops) == "number", "Bad maxLoops")
	assert(SoundLoopScheduleUtils.isLoopedSchedule(loopedSchedule) or loopedSchedule == nil, "Bad loopedSchedule")

	loopedSchedule = loopedSchedule or {}
	return SoundLoopScheduleUtils.schedule(Table.merge(loopedSchedule, {
		maxLoops = maxLoops,
	}))
end

function SoundLoopScheduleUtils.default(): SoundLoopSchedule
	return SoundLoopScheduleUtils.schedule({})
end

SoundLoopScheduleUtils.isWaitTimeSeconds = t.union(t.number, t.NumberRange)

SoundLoopScheduleUtils.isLoopedSchedule = t.interface({
	playOnNextLoop = t.optional(t.boolean),
	maxLoops = t.optional(t.number),
	initialDelay = t.optional(SoundLoopScheduleUtils.isWaitTimeSeconds),
	loopDelay = t.optional(SoundLoopScheduleUtils.isWaitTimeSeconds),
	maxInitialWaitTimeForNextLoop = t.optional(SoundLoopScheduleUtils.isWaitTimeSeconds),
})

export type SoundLoopSchedule = {
	playOnNextLoop: boolean?,
	maxLoops: number?,
	initialDelay: number | NumberRange?,
	loopDelay: number | NumberRange?,
	maxInitialWaitTimeForNextLoop: number | NumberRange?,
}

function SoundLoopScheduleUtils.getWaitTimeSeconds(waitTime: number | NumberRange): number
	assert(SoundLoopScheduleUtils.isWaitTimeSeconds(waitTime))

	if type(waitTime) == "number" then
		return waitTime
	elseif typeof(waitTime) == "NumberRange" then
		return NumberRangeUtils.getValue(waitTime, math.random())
	else
		error("Bad waitTime")
	end
end

return SoundLoopScheduleUtils
