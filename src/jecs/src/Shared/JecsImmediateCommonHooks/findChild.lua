--!nonstrict
--[=[
	@class findChild
]=]

local require = require(script.Parent.Parent.loader).load(script)

local JecsImmediateInstall = require("JecsImmediateInstall")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: JecsImmediateInstall.ImmediateRuntime_Jecs)
	return function(dis: any?, parentInstance: Instance, name: string, recursive: boolean?)
		if not parentInstance then
			error(`parentInstance is nil: {dis} {name} {recursive}`)
		end
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)
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
	end
end
