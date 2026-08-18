--!nonstrict
--[=[
	@class useTieInterface

	Returns the latest tie interface. Uses brio to cleanup itself.
]=]

local require = require(script.Parent.Parent.loader).load(script)

local JecsImmediateInstall = require("JecsImmediateInstall")
local TieRealms = require("TieRealms")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: JecsImmediateInstall.ImmediateRuntime_Jecs)
	return function(dis, instance: Instance, tieInterfaceName: string, realm: TieRealms.TieRealm?)
		local hookState, hookMaid = getOrCreateHookState(rt, dis)
		if hookState.observingBrio == nil then
			-- listens and always updates the current interface
			local tieInterface = rt.require(tieInterfaceName)
			if realm then
				tieInterface = tieInterface[realm]
			end
			hookState.observingBrio = hookMaid:GiveTask(tieInterface:ObserveBrio(instance):Subscribe(function(brio)
				if brio:IsDead() then
					hookState.currentInterface = nil
					return
				end
				local _maid, interface = brio:ToMaidAndValue()
				hookState.currentInterface = interface
			end))
		end
		return hookState.currentInterface
	end
end
