--!nonstrict
--[=[
	@class cache
]=]

local require = require(script.Parent.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local Maid = require("Maid")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(dis: any?, cacheFunction: (maid: Maid.Maid) -> any, cleanup: (value: any) -> any, debug: boolean?)
		if debug then
			print(`cache: called with dis {dis}`)
		end
		local hookState, hookMaid = getOrCreateHookState(rt, dis)
		if hookState.cachedValue == nil then
			hookState.cachedValue = table.pack(cacheFunction(hookMaid))
			hookState.cleanup = cleanup
			local cachedValue = hookState.cachedValue

			hookMaid:GiveTask(function()
				if cachedValue == nil then
					return
				end
				if cleanup then
					cleanup(table.unpack(cachedValue))
				end
			end)
		end
		return table.unpack(hookState.cachedValue)
	end
end
