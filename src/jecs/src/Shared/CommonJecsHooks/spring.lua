--!nonstrict
--[=[
	@class spring

	Springs a number / Vector2 / Vector3 / Color3, or a CFrame.

	CFrame uses three Vector3 springs (position, look, up) and returns
	`(CFrame, nil)` — there is no single Spring object for that path.
]=]

local require = require(script.Parent.Parent.loader).load(script)

local ImmediateHookSpringUtils = require("ImmediateHookSpringUtils")
local ImmediateTypes = require("ImmediateTypes")
local Spring = require("Spring")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

local function usesCFrame(goal: any?, value: any?): boolean
	if goal ~= nil then
		return typeof(goal) == "CFrame"
	end
	if value ~= nil then
		return typeof(value) == "CFrame"
	end
	return false
end

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(dis: any?, goal: any?, value: any?, speed: number?, damping: number?): (any, Spring.Spring<any>?)
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)

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
