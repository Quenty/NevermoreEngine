--!nonstrict
--[=[
	@class subscribe
]=]

local require = require(script.Parent.Parent.loader).load(script)

local ImmediateJecsUtils = require("ImmediateJecsUtils")
local ImmediateTypes = require("ImmediateTypes")
local Observable = require("Observable")
local Rx = require("Rx")
local Signal = require("Signal")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(
		subscribable: Observable.Observable<any> | Signal.Signal<any>,
		dis: any?,
		returnLastEmittedOnly: boolean?
	)
		local function toObservable(source: Observable.Observable<any> | Signal.Signal<any>): Observable.Observable<any>
			if typeof(source) == "RBXScriptSignal" or Signal.isSignal(source) then
				return Rx.fromSignal(source :: Signal.Signal<any>)
			end
			if Observable.isObservable(source) then
				return source :: Observable.Observable<any>
			end
			-- RemotingMember and other Connect()-able tables
			return Rx.fromSignal(source :: Signal.Signal<any>)
		end

		local hookState, hookMaid = getOrCreateHookState(rt, dis)

		if hookState.collector == nil then
			hookState.collector =
				hookMaid:Add(ImmediateJecsUtils.collectObservable(toObservable(subscribable), hookMaid))
		end

		local collector = hookState.collector
		assert(collector, "subscribe hook collector missing")

		if returnLastEmittedOnly then
			return collector.Last()
		end
		return collector.Drain()
	end
end
