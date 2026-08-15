--!nonstrict
--[=[
	@class spring
]=]

local require = require(script.Parent.loader).load(script)

local ImmediateHookSpringUtils = require("ImmediateHookSpringUtils")
local ImmediateTypes = require("ImmediateTypes")
local Spring = require("Spring")
local getOrCreateHookState = require("ImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(dis: any?, goal: any?, value: any?, speed: number?, damping: number?): (any, Spring.Spring<any>)
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)

		if hookState.springIsColor3 == nil then
			hookState.springIsColor3 = ImmediateHookSpringUtils.usesColor3(goal, value)
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
			local initial = ImmediateHookSpringUtils.internalValue(initialSource)
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
			hookState.spring.Target = ImmediateHookSpringUtils.internalValue(goal)
		end

		local position = ImmediateHookSpringUtils.externalValue(hookState.spring.Position, isColor3)
		return position, hookState.spring
	end
end
