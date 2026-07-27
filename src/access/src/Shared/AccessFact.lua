--!strict
--[=[
	One layer of one fact about a player: `true`, `false`, or `nil` for not-yet-answered. Facts are never
	gated by a release flag and never consult each other -- "does this player own the pass" is the same
	question whether or not the game has launched. What a fact *means* is [AccessFeature]'s business.

	Two ways to answer, and the difference is per-player versus game-wide:

	```lua
	-- Per-player: a resolver, run once per player and shared between every consumer.
	AccessFact.new("ownsFullAccessPass", {
		resolve = function(serviceBag, player)
			return serviceBag:GetService(GameProductDataService)
				:ObservePlayerOwnership(player, GameConfigAssetTypes.PASS, FULL_ACCESS_GAME_PASS_KEY)
		end,
	})

	-- Game-wide: one [ValueObject.Mountable] every player reads the same answer from.
	AccessFact.new("eventIsRunning", { value = eventRunningValueObject })
	```

	Several layers may answer the same fact -- a group rank and an allowlist both saying whether someone is
	staff. Each declares an [AccessFactPriority], and the highest layer that *contributes* decides. Return
	[AccessFact.ABSTAIN] to contribute nothing and let a lower layer answer; returning `nil` is an answer,
	and the answer is "unresolved".

	GOTCHA: a fact resolves in whichever realm asks it, so a resolver that only works on the server leaves
	the client permanently unresolved -- and every feature declaring that fact never settles there. Resolve
	server-side work into a replicated player attribute and have the resolver read *that* in both realms.

	@class AccessFact
]=]

local require = require(script.Parent.loader).load(script)

local AccessFactPriority = require("AccessFactPriority")
local BaseObject = require("BaseObject")
local Observable = require("Observable")
local Rx = require("Rx")
local RxAccessStateUtils = require("RxAccessStateUtils")
local RxValueBaseUtils = require("RxValueBaseUtils")
local ServiceBag = require("ServiceBag")
local ValueBaseUtils = require("ValueBaseUtils")
local ValueObject = require("ValueObject")

local AccessFact = setmetatable({}, BaseObject)
AccessFact.ClassName = "AccessFact"
AccessFact.__index = AccessFact

--[=[
	Returned by a resolver that has nothing to say, so a lower-priority layer answers instead.

	Distinct from `nil` on purpose. `nil` means "I am the one answering, and my answer is that nobody
	knows yet" -- which stops the fall-through, and is what lets a console override force a fact to
	unresolved without a real lookup quietly filling it back in.

	@prop ABSTAIN userdata
	@within AccessFact
]=]
AccessFact.ABSTAIN = newproxy(false)

--[=[
	What a layer said. `nil` for the whole contribution means the layer abstained; a contribution whose
	`value` is nil means the layer answered "unresolved".

	@type AccessFactContribution { value: boolean? }?
	@within AccessFact
]=]
export type AccessFactContribution = { value: boolean? }?

--[=[
	Resolves the fact for one player. Returns anything [ValueObject.Mountable] accepts, so a test can hand
	back a bare `true` where production hands back an observable -- or [AccessFact.ABSTAIN].

	@type AccessFactResolver (ServiceBag, Player) -> ValueObject.Mountable<boolean?>
	@within AccessFact
]=]
export type AccessFactResolver = (serviceBag: ServiceBag.ServiceBag, player: Player) -> any

--[=[
	Exactly one of `resolve` or `value`. An options table rather than a positional resolver because a fact
	has more to say about itself than its answer -- where it sits, what to call it in a readout.

	`source` labels this layer in a debug readout. It only has to be unique among layers of the same fact,
	so the default is fine until you add a second layer, at which point registration makes you name it.

	@interface AccessFactOptions
	.resolve AccessFactResolver? -- per-player
	.value ValueObject.Mountable<boolean?>? -- game-wide
	.priority number? -- defaults to AccessFactPriority.DEFAULT
	.source string? -- label for readouts, defaults to "default"
	@within AccessFact
]=]
export type AccessFactOptions = {
	resolve: AccessFactResolver?,
	value: ValueObject.Mountable<boolean?>?,
	priority: number?,
	source: string?,
}

local DEFAULT_SOURCE = "default"

export type AccessFact =
	typeof(setmetatable(
		{} :: {
			_factName: string,
			_priority: number,
			_source: string,
			_resolve: AccessFactResolver,
			_serviceBag: ServiceBag.ServiceBag?,
			-- Weak keys: a player who left is collected along with their cached observable, so nothing has to
			-- watch PlayerRemoving to evict -- which also keeps this working for a PlayerMock in tests.
			_observableByPlayer: { [any]: Observable.Observable<AccessFactContribution> },
		},
		{} :: typeof({ __index = AccessFact })
	))
	& BaseObject.BaseObject

--[=[
	@param factName string
	@param options AccessFactOptions
	@return AccessFact
]=]
function AccessFact.new(factName: string, options: AccessFactOptions): AccessFact
	assert(type(factName) == "string" and factName ~= "", "Bad factName")
	assert(type(options) == "table", "Bad options")
	assert(options.resolve ~= nil or options.value ~= nil, "Bad options, one of resolve or value is required")
	assert(options.resolve == nil or options.value == nil, "Bad options, resolve and value are exclusive")
	assert(type(options.priority) == "number" or options.priority == nil, "Bad options.priority")
	assert(type(options.source) == "string" or options.source == nil, "Bad options.source")

	local self: AccessFact = setmetatable(BaseObject.new() :: any, AccessFact)

	self._factName = factName
	self._priority = options.priority or AccessFactPriority.DEFAULT
	self._source = options.source or DEFAULT_SOURCE
	self._observableByPlayer = setmetatable({}, { __mode = "k" }) :: any

	if options.resolve ~= nil then
		assert(type(options.resolve) == "function", "Bad options.resolve")

		self._resolve = options.resolve
	else
		-- Converted once rather than per player: every player shares the one answer, so they may as well
		-- share the one observable.
		local observable = AccessFact._toObservable(options.value)

		self._resolve = function()
			return observable
		end
	end

	return self
end

--[=[
	@param value any
	@return boolean
]=]
function AccessFact.isAccessFact(value: any): boolean
	return type(value) == "table" and getmetatable(value) == AccessFact
end

--[=[
	Stores the [ServiceBag] resolvers are handed. Called by [AccessDataService] on registration.

	@param serviceBag ServiceBag
]=]
function AccessFact.Init(self: AccessFact, serviceBag: ServiceBag.ServiceBag): ()
	assert(not self._serviceBag, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
end

--[=[
	@return string
]=]
function AccessFact.GetFactName(self: AccessFact): string
	return self._factName
end

--[=[
	@return number
]=]
function AccessFact.GetPriority(self: AccessFact): number
	return self._priority
end

--[=[
	@return string
]=]
function AccessFact.GetSource(self: AccessFact): string
	return self._source
end

--[=[
	What this layer says about the player, live.

	Emits immediately -- unresolved until the resolver answers -- so a consumer always has something to
	render, and so [Rx.combineLatest] over several layers starts producing at once rather than waiting on
	the slowest lookup.

	One resolver run is shared between every concurrent subscriber -- the fan-in that stops five surfaces
	from opening five copies of the same ownership lookup. The share is refcounted, so the resolver is torn
	down once nobody is listening and re-run for whoever asks next.

	@param player Player
	@return Observable<AccessFactContribution>
]=]
function AccessFact.ObserveForPlayer(self: AccessFact, player: Player): Observable.Observable<AccessFactContribution>
	assert(player, "Bad player")

	local existing = self._observableByPlayer[player]
	if existing then
		return existing
	end

	local serviceBag = assert(self._serviceBag, "AccessFact is not initialized")

	local observable = Observable.new(function(sub)
		return AccessFact._toObservable(self._resolve(serviceBag, player)):Subscribe(sub:GetFireFailComplete())
	end):Pipe({
		RxAccessStateUtils.unresolvedOnError() :: any,
		RxAccessStateUtils.startUnresolved() :: any,
		Rx.map(function(value: any): AccessFactContribution
			if value == AccessFact.ABSTAIN then
				return nil
			end

			return { value = value }
		end) :: any,
		Rx.shareReplay(1) :: any,
	}) :: any

	self._observableByPlayer[player] = observable

	return observable
end

--[=[
	Drops the cached resolution for a player who is gone. The cache is weak-keyed as well, but GC is not a
	schedule -- a departed player's ownership lookup should stop being subscribable the moment they leave,
	not whenever the collector next runs.

	@param player Player
]=]
function AccessFact.RemovePlayer(self: AccessFact, player: Player): ()
	self._observableByPlayer[player] = nil
end

--[=[
	A plain snapshot of this layer, for printing while you reason about a registry.

	@return { factName: string, priority: number, source: string }
]=]
function AccessFact.GetDebugState(self: AccessFact): { factName: string, priority: number, source: string }
	return {
		factName = self._factName,
		priority = self._priority,
		source = self._source,
	}
end

-- ValueObject.Mountable, unrolled. ValueObject itself only exposes this through Mount, which would mean
-- owning a ValueObject per player just to read one value out of it.
function AccessFact._toObservable(value: any): Observable.Observable<any>
	if value == AccessFact.ABSTAIN then
		return RxAccessStateUtils.ofStatic(AccessFact.ABSTAIN :: any)
	elseif Observable.isObservable(value) then
		return value :: any
	elseif typeof(value) == "Instance" then
		if ValueBaseUtils.isValueBase(value) then
			return RxValueBaseUtils.observeValue(value) :: any
		end

		error(`[AccessFact] - Cannot resolve a fact from a {value.ClassName}`)
	elseif type(value) == "table" and ValueObject.isValueObject(value) then
		return (value :: any):Observe()
	elseif type(value) == "boolean" or value == nil then
		return RxAccessStateUtils.ofStatic(value :: boolean?)
	end

	error(`[AccessFact] - Cannot resolve a fact from a {typeof(value)}`)
end

return AccessFact
