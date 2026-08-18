--!nonstrict
--[=[
	@class hookEntity

	Returns a brand new entity that is a child of the hook entity.
	Will thus be instantly deleted if the hook is cleaned up/not visited,
	so you don't have to write the cleanup/entity delete.
]=]

local require = require(script.Parent.Parent.loader).load(script)

local JecsImmediateInstall = require("JecsImmediateInstall")
local Jecs = require("Jecs")
local Jecst = require("Jecst")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: JecsImmediateInstall.ImmediateRuntime_Jecs)
	return function(dis, initDecorator: (Jecst.Entity) -> any?)
		local hookState, _hookMaid, hookStateEntity = getOrCreateHookState(rt, dis)
		if not hookState.childEntity then
			hookState.childEntity = rt.world:entity()
			rt.world:add(hookState.childEntity, Jecs.pair(rt.comps.ChildOf, hookStateEntity))
			if initDecorator then
				initDecorator(hookState.childEntity)
			end
		end
		return hookState.childEntity
	end
end
