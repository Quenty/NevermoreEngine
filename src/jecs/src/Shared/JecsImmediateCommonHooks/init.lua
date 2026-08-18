--!strict
--[=[
	@class JecsImmediateCommonHooks

	Assembles the built-in hook factories. ImmediateHooksInstall attaches these
	to the runtime.

	Keep the global `require` unshadowed so `require(script.X)` preserves each
	hook factory's return type. Loader requires would type every hook as `any`.
]=]

-- local nevermoreRequire = require(script.Parent.loader).load(script)

-- local JecsImmediateInstall = nevermoreRequire("JecsImmediateInstall")

--[[

	As of now, there's no way to magically gather the types of modules underneath a folder
	so we're just manually requiring them here.
	If a new hook is added to commonhooks, it'll need to be added here too.
	The pattern for any new custom hooks you'd use would to be to return a dictionary,
	with [hookName] = hookFunctionFactory(rt), which will give you a function that's aware of the
	runtime state.






	okay maybe i need to split these up into discrete modules that can be combined into one giga dictionary
	and just return to good ol functions inside a big ahh table

]]

return function(rt)
	return {
		async = require(script.async)(rt),
		cache = require(script.cache)(rt),
		changed = require(script.changed)(rt),
		conditionSustained = require(script.conditionSustained)(rt),
		counter = require(script.counter)(rt),
		delayed = require(script.delayed)(rt),
		delta = require(script.delta)(rt),
		deltatime = require(script.deltatime)(rt),
		difference = require(script.difference)(rt),
		draw = require(script.draw)(rt),
		entity = require(script.entity)(rt),
		filterDescendants = require(script.filterDescendants)(rt),
		findChild = require(script.findChild)(rt),
		gate = require(script.gate)(rt),
		gatecounter = require(script.gatecounter)(rt),
		hookEntity = require(script.hookEntity)(rt),
		linearWalk = require(script.linearWalk)(rt),
		maid = require(script.maid)(rt),
		noise = require(script.noise)(rt),
		random = require(script.random)(rt),
		randomChoice = require(script.randomChoice)(rt),
		rtbuffer = require(script.rtbuffer)(rt),
		scheduledValues = require(script.scheduledValues)(rt),
		scheduler = require(script.scheduler)(rt),
		sin = require(script.sin)(rt),
		slidingAvg = require(script.slidingAvg)(rt),
		spring = require(script.spring)(rt),
		state = require(script.state)(rt),
		subscribe = require(script.subscribe)(rt),
		throttle = require(script.throttle)(rt),
		throttledSetQueue = require(script.throttledSetQueue)(rt),
		tween = require(script.tween)(rt),
		value = require(script.value)(rt),
		useBinder = require(script.useBinder)(rt),
		useTieInterface = require(script.useTieInterface)(rt),
	}
end
