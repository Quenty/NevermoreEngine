--!strict
--[=[
	Observable plumbing for access. The tri-state -- `true | false | nil` -- has to travel through
	observables like any other value, and none of the obvious [Rx] operators carry `nil`:

	* `Rx.startWith({nil})` iterates its list, and a Lua list cannot hold nil, so it fires nothing.
	* `Rx.defaultsTo(nil)` only fires on fail or complete, so a lookup still in flight emits nothing at all.
	* `Rx.of(nil)` relies on varargs packing surviving a lone nil, and completes besides.

	That matters because [Rx.combineLatest] waits for every source to emit once. A fact that stays silent
	until its lookup lands would keep the whole feature from emitting -- so a live consumer renders nothing
	instead of rendering "not yet known".

	@class RxAccessStateUtils
]=]

local require = require(script.Parent.loader).load(script)

local AccessStateUtils = require("AccessStateUtils")
local Observable = require("Observable")

local RxAccessStateUtils = {}

--[=[
	A fact that is always this value.

	GOTCHA: deliberately never completes. [Rx.of] does, and a completed source defeats [Rx.shareReplay] --
	every subscriber completes, the share drops its upstream, and the next reader re-runs the resolver from
	scratch. A fact is a live value that happens not to change, not a stream that ended.

	@param value boolean?
	@return Observable<boolean?>
]=]
function RxAccessStateUtils.ofStatic(value: boolean?): Observable.Observable<boolean?>
	return Observable.new(function(sub)
		sub:Fire(value)

		return nil
	end) :: any
end

--[=[
	Emits unresolved immediately, then everything the source emits.

	@return (Observable<boolean?>) -> Observable<boolean?>
]=]
function RxAccessStateUtils.startUnresolved(): any
	return function(source: any): any
		return Observable.new(function(sub)
			sub:Fire(nil)

			return source:Subscribe(sub:GetFireFailComplete())
		end)
	end
end

--[=[
	Turns a failing source into an unresolved one. A fact whose lookup blew up has not answered, which is
	exactly what unresolved means -- and one broken mechanism must not fail every feature reading it.

	@return (Observable<boolean?>) -> Observable<boolean?>
]=]
function RxAccessStateUtils.unresolvedOnError(): any
	return function(source: any): any
		return Observable.new(function(sub)
			return source:Subscribe(function(value: boolean?)
				sub:Fire(value)
			end, function()
				sub:Fire(nil)
			end, function()
				sub:Complete()
			end)
		end)
	end
end

--[=[
	Suppresses repeats of the same verdict.

	[Rx.distinct] compares by reference and every computed state is a fresh table, so it would suppress
	nothing. This compares the verdict, via [AccessStateUtils.key].

	@return (Observable<AccessStateUtils.AccessState>) -> Observable<AccessStateUtils.AccessState>
]=]
function RxAccessStateUtils.distinctState(): any
	return function(source: any): any
		return Observable.new(function(sub)
			local lastKey: string? = nil

			return source:Subscribe(function(state: AccessStateUtils.AccessState)
				local key = AccessStateUtils.key(state)
				if key == lastKey then
					return
				end

				lastKey = key
				sub:Fire(state)
			end, sub:GetFailComplete())
		end)
	end
end

--[=[
	Ends the stream when the notifier fires, completing it rather than merely dropping it.

	[Rx.takeUntil] cancels its upstream subscription but never calls `Complete`, so a consumer is left
	holding a stream that has silently stopped -- indistinguishable from one that is simply quiet. A
	session ending is something a subscriber needs to be told about, not something it should have to
	infer.

	@param notifier Observable
	@return (Observable<T>) -> Observable<T>
]=]
function RxAccessStateUtils.completeOn(notifier: any): any
	assert(Observable.isObservable(notifier), "Bad notifier")

	return function(source: any): any
		return Observable.new(function(sub)
			local done = false
			local sourceSub: any = nil

			local function finish()
				if done then
					return
				end
				done = true

				sub:Complete()

				if sourceSub then
					sourceSub:Destroy()
					sourceSub = nil
				end
			end

			local notifierSub = notifier:Subscribe(finish, finish, nil)

			-- Already fired -- a player who left before anyone asked. Complete without ever subscribing to
			-- a source whose answer nobody is waiting for.
			if done then
				notifierSub:Destroy()
				return nil
			end

			sourceSub = source:Subscribe(sub:GetFireFailComplete())

			return function()
				notifierSub:Destroy()
				if sourceSub then
					sourceSub:Destroy()
					sourceSub = nil
				end
			end
		end)
	end
end

return RxAccessStateUtils
