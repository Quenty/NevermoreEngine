--!nonstrict
--[=[
	@class draw
]=]

local require = require(script.Parent.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(drawnThing: any, dis: any?)
		local _hookState, _hookMaid = getOrCreateHookState(rt, dis)
		_hookMaid._currentlyDrawnThing = drawnThing
		return drawnThing
	end
end
