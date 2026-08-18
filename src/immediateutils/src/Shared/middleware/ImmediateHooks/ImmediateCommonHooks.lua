--!nonstrict
--[=[
	@class ImmediateCommonHooks

	Assembles the built-in hook factories under middleware/ImmediateHooks/commonhooks.
	ImmediateHooksInstall attaches these to the runtime.
]=]

local rawrequire = require
local require = require(script.Parent.loader).load(script)

local ImmediateHookUtils = require("ImmediateHookUtils")
local ImmediateTypes = require("ImmediateTypes")

local ImmediateCommonHooks = {}

--[[

	As of now, there's no way to magically gather the types of modules underneath a folder
	so we're just manually requiring them here.
	If a new hook is added to commonhooks, it'll need to be added here too.
	The pattern for any new custom hooks you'd use would to be to return a dictionary,
	with [hookName] = hookFunctionFactory(rt), which will give you a function that's aware of the
	runtime state.

]]

function ImmediateCommonHooks._createHookCallbacks(rt: ImmediateTypes.ImmediateRuntime)
	local hooksFolder = require("CommonJecsHooks").script
	local hooks = {
		async = rawrequire(hooksFolder.async)(rt),
		cache = rawrequire(hooksFolder.cache)(rt),
		changed = rawrequire(hooksFolder.changed)(rt),
		conditionSustained = rawrequire(hooksFolder.conditionSustained)(rt),
		counter = rawrequire(hooksFolder.counter)(rt),
		delayed = rawrequire(hooksFolder.delayed)(rt),
		delta = rawrequire(hooksFolder.delta)(rt),
		deltatime = rawrequire(hooksFolder.deltatime)(rt),
		difference = rawrequire(hooksFolder.difference)(rt),
		draw = rawrequire(hooksFolder.draw)(rt),
		entity = rawrequire(hooksFolder.entity)(rt),
		filterDescendants = rawrequire(hooksFolder.filterDescendants)(rt),
		findChild = rawrequire(hooksFolder.findChild)(rt),
		gate = rawrequire(hooksFolder.gate)(rt),
		gatecounter = rawrequire(hooksFolder.gatecounter)(rt),
		hookEntity = rawrequire(hooksFolder.hookEntity)(rt),
		linearWalk = rawrequire(hooksFolder.linearWalk)(rt),
		maid = rawrequire(hooksFolder.maid)(rt),
		noise = rawrequire(hooksFolder.noise)(rt),
		random = rawrequire(hooksFolder.random)(rt),
		randomChoice = rawrequire(hooksFolder.randomChoice)(rt),
		rtbuffer = rawrequire(hooksFolder.rtbuffer)(rt),
		scheduledValues = rawrequire(hooksFolder.scheduledValues)(rt),
		scheduler = rawrequire(hooksFolder.scheduler)(rt),
		sin = rawrequire(hooksFolder.sin)(rt),
		slidingAvg = rawrequire(hooksFolder.slidingAvg)(rt),
		spring = rawrequire(hooksFolder.spring)(rt),
		state = rawrequire(hooksFolder.state)(rt),
		subscribe = rawrequire(hooksFolder.subscribe)(rt),
		throttle = rawrequire(hooksFolder.throttle)(rt),
		throttledSetQueue = rawrequire(hooksFolder.throttledSetQueue)(rt),
		tween = rawrequire(hooksFolder.tween)(rt),
		value = rawrequire(hooksFolder.value)(rt),
		useBinder = rawrequire(hooksFolder.useBinder)(rt),
		useTieInterface = rawrequire(hooksFolder.useTieInterface)(rt),
	}
	return hooks
end

export type ImmediateHookCallbacks = typeof(ImmediateCommonHooks._createHookCallbacks(
	{} :: ImmediateTypes.ImmediateRuntime
))

export type ImmediateHooksAddon = ImmediateHookUtils.ImmediateHookBookAddon & {
	hooks: ImmediateHookCallbacks,
}

export type ImmediateRuntimeWithHooks<C = {}, B = {}> = ImmediateTypes.ImmediateRuntime<C, B> & ImmediateHooksAddon

return ImmediateCommonHooks
