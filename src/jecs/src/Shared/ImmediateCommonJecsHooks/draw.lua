--!nonstrict
--[=[
	@class draw
]=]

local require = require(script.Parent.Parent.loader).load(script)

local JecsImmediateInstall = require("JecsImmediateInstall")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: JecsImmediateInstall.ImmediateRuntime_Jecs)
	return function(drawnThing: any, dis: any?)
		local _hookState, _hookMaid = getOrCreateHookState(rt, dis)
		_hookMaid._currentlyDrawnThing = drawnThing
		return drawnThing
	end
end
