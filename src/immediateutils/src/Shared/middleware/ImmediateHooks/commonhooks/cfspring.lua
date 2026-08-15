--!nonstrict
--[=[
	@class cfspring
]=]

local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local Spring = require("Spring")
local getOrCreateHookState = require("ImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(
		dis: any?,
		goalCF: CFrame,
		startCF: CFrame?,
		speed: number?,
		damping: number?
	): (CFrame, Spring.Spring<any>)
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)

		if not hookState.springPos then
			local finalStartCF = startCF
			if not startCF then
				finalStartCF = goalCF
			end
			hookState.springPos = Spring.new(finalStartCF.Position)
			hookState.springPos.Position = finalStartCF.Position
			hookState.springPos.Speed = 10
			hookState.springPos.Damper = 1
			hookState.springLookAlong = Spring.new(finalStartCF.LookVector)
			hookState.springLookAlong.Position = finalStartCF.LookVector
			hookState.springLookAlong.Speed = 10
			hookState.springLookAlong.Damper = 1
			hookState.springUpVector = Spring.new(finalStartCF.UpVector)
			hookState.springUpVector.Position = finalStartCF.UpVector
			hookState.springUpVector.Speed = 10
			hookState.springUpVector.Damper = 1
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

		hookState.finalCFrame = CFrame.lookAlong(
			hookState.springPos.Position,
			hookState.springLookAlong.Position,
			hookState.springUpVector.Position
		)
		assert(goalCF, "goalCF is nil")
		hookState.springPos.Target = goalCF.Position
		hookState.springLookAlong.Target = goalCF.LookVector
		hookState.springUpVector.Target = goalCF.UpVector

		return hookState.finalCFrame, hookState.spring
	end
end
