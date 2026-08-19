--!nonstrict
--[=[
	@class JecsImmediateHooksCommonHooksInstall

	Addon that *introduces* `rt.hooks` as a new top-level field.

	Luau will not overlay a nested key: `Rt & { hooks: Extra }` when `Rt` already
	has `hooks` becomes `hooks: Old & Extra`, which autocomplete does not flatten.
	This installer therefore takes a hook-book runtime with no `hooks` type and
	returns `Rt & { hooks: Common & Extra }` — the same shape as DeferInstall
	adding `defer`.
]=]
local require = require(script.Parent.loader).load(script)

-- local ImmediateScheduler = require("ImmediateScheduler")
-- local JecsImmediateCommonHooks = require("JecsImmediateCommonHooks")
local JecsImmediateHookUtils = require("JecsImmediateHookUtils")
local Maid = require("Maid")

local function _hooks<Rt>(rt: JecsImmediateHookUtils.ImmediateRuntime_Jecs_HookBook<Rt>)
	return {
		async = function(dis: any?, asyncFunction: ({ any }, Maid.Maid) -> any)
			type AsyncHookState = {
				_startedAsync: boolean?,
				_ret: { any },
			}
			local hookState: AsyncHookState, hookMaid = JecsImmediateHookUtils.getOrCreateHookState(rt, dis)

			if hookState._startedAsync == nil then
				hookState._startedAsync = true
				hookState._ret = {}
				hookMaid:GiveTask(task.spawn(function()
					asyncFunction(hookState._ret, hookMaid)
				end))
			end
			return hookState._ret
		end,
		cache = function(
			cacheFunction: (maid: Maid.Maid) -> any,
			cleanup: (value: any) -> any,
			dis: any?,
			debug: boolean?
		)
			type CacheHookState = {
				cachedValue: { any },
				cleanup: (value: any) -> any,
			}
			if debug then
				print(`cache: called with dis {dis}`)
			end
			local hookState: CacheHookState, hookMaid = JecsImmediateHookUtils.getOrCreateHookState(rt, dis)
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
		end,
		changed = function(value: any, dis: any?, runFirst: boolean?, onlyOnEqualTo: any?)
			local hookState, _hookMaid = JecsImmediateHookUtils.getOrCreateHookState(rt, dis)

			if hookState.lastValue == nil then
				hookState.lastValue = value
				if onlyOnEqualTo ~= nil then
					return value == onlyOnEqualTo
				end
				if runFirst == true then
					return true
				end
				return false
			end

			if hookState.lastValue ~= value then
				hookState.lastValue = value
				if onlyOnEqualTo ~= nil then
					return value == onlyOnEqualTo
				else
					return true
				end
			end

			return false
		end,
	}
end

type HooksTable = { [string]: (any) -> any }
type WithHooks<HooksTable> = HooksTable & typeof(_hooks({} :: JecsImmediateHookUtils.ImmediateRuntime_Jecs_HookBook))

return function<Rt, HooksTable>(
	rt: JecsImmediateHookUtils.ImmediateRuntime_Jecs_HookBook<Rt>,
	hooksTable: HooksTable
): WithHooks<HooksTable>
	for hookName, hookFunction in _hooks(rt) do
		(hooksTable :: any)[hookName] = hookFunction(rt)
	end
	return hooksTable :: WithHooks<HooksTable>
end
