--!strict
--[=[
	One layer of one fact about a player: `true`, `false`, or `nil` for not-yet-answered. Facts are never
	gated by a release flag and never consult each other -- "does this player own the pass" is the same
	question whether or not the game has launched. What a fact *means* is [AccessFeature]'s business.

	Two ways to answer, and the difference is per-player versus game-wide:

	```lua
	-- Per-player: a resolver, run once per player and shared between every consumer.
	maid:Add(AccessFact.new("ownsFullAccessPass", {
		resolve = function(serviceBag, player)
			return serviceBag:GetService(GameProductDataService)
				:ObservePlayerOwnership(player, GameConfigAssetTypes.PASS, FULL_ACCESS_GAME_PASS_KEY)
		end,
	}))

	-- Game-wide: one [ValueObject.Mountable] every player reads the same answer from.
	maid:Add(AccessFact.new("eventIsRunning", { value = eventRunningValueObject }))
	```

	A fact has a lifetime -- it holds a shared observable per player -- so give it to a maid where you make
	it. Registering it does not take ownership.

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

local AccessFactContributionState = require("AccessFactContributionState")
local AccessFactContributionStateUtils = require("AccessFactContributionStateUtils")
local AccessFactPriority = require("AccessFactPriority")
local AccessFactServerOverrideBehavior = require("AccessFactServerOverrideBehavior")
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
	An answer with attribution attached. Use where "yes" alone is not enough for the UI you will build:
	"you own this" is less useful than "you own this because of gamepass 12345", and a friend-granted
	fact is nearly useless without knowing *which* friend.

	```lua
	resolve = function(_serviceBag, player)
		return observeFriendGrant(player):Pipe({
			Rx.map(function(friend)
				return AccessFact.contribution(friend ~= nil, { grantedByUserId = friend })
			end),
		})
	end
	```

	@param value boolean?
	@param metadata any?
	@return AccessFactContribution
]=]
function AccessFact.contribution(value: boolean?, metadata: any?): AccessFactContribution
	return {
		state = AccessFactContributionStateUtils.fromValue(value),
		value = value,
		metadata = metadata,
	}
end

--[=[
	A contribution in a state directly, for the states no boolean can express.

	@param state string
	@param metadata any?
	@return AccessFactContribution
]=]
function AccessFact.contributionOfState(state: string, metadata: any?): AccessFactContribution
	assert(AccessFactContributionStateUtils.isContributionState(state), "Bad state")

	return {
		state = state,
		value = AccessFactContributionStateUtils.toValue(state),
		metadata = metadata,
	}
end

--[=[
	@param value any
	@return boolean
]=]
function AccessFact.isContribution(value: any): boolean
	return type(value) == "table" and AccessFactContributionStateUtils.isContributionState(rawget(value, "state"))
end

--[=[
	Returned by a resolver that has nothing to say, so a lower-priority layer answers instead. Sugar for
	[AccessFactContributionState].ABSTAIN.

	Distinct from returning `nil`, which means "I am answering, and my answer is that nobody knows yet".
	One is silence and the other is an answer; they behave differently in the merge, and naming both is
	what stopped that difference from living in a nil.

	@prop ABSTAIN userdata
	@within AccessFact
]=]
AccessFact.ABSTAIN = newproxy(false)

--[=[
	What a layer said: an [AccessFactContributionState] plus, for the states that carry one, the boolean
	it means. Always a table -- there is no nil contribution any more, because a nil could not be told
	apart from a layer that said nothing and could not survive being put in a map.

	`metadata` is why it said so, in whatever shape the mechanism has: which friend granted access, which
	gamepass was owned, which allowlist matched. Opaque to this package -- it is carried, printed and
	handed back, never interpreted -- because only the mechanism knows what is worth attributing.

	@type AccessFactContribution { value: boolean? }?
	@within AccessFact
]=]
export type AccessFactContribution = {
	state: string,
	value: boolean?,
	metadata: any?,
}

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
	.serverOverrideBehavior string? -- see AccessFactServerOverrideBehavior, defaults to allow-only
	@within AccessFact
]=]
export type AccessFactOptions = {
	resolve: AccessFactResolver?,
	value: ValueObject.Mountable<boolean?>?,
	priority: number?,
	source: string?,
	serverOverrideBehavior: string?,
}

local DEFAULT_SOURCE = "default"

export type AccessFact =
	typeof(setmetatable(
		{} :: {
			_factName: string,
			_priority: number,
			_source: string,
			_serverOverrideBehavior: string,
			_resolve: AccessFactResolver,
			_serviceBag: ServiceBag.ServiceBag?,
			-- Weak keys: a player who left is collected along with their cached observable, so nothing has to
			-- watch PlayerRemoving to evict -- which also keeps this working for a PlayerMock in tests.
			_observableByPlayer: { [any]: any },
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
	assert(
		options.serverOverrideBehavior == nil
			or AccessFactServerOverrideBehavior.isBehavior(options.serverOverrideBehavior),
		"Bad options.serverOverrideBehavior"
	)

	local self: AccessFact = setmetatable(BaseObject.new() :: any, AccessFact)

	self._factName = factName
	self._priority = options.priority or AccessFactPriority.DEFAULT
	self._source = options.source or DEFAULT_SOURCE
	self._serverOverrideBehavior = options.serverOverrideBehavior or AccessFactServerOverrideBehavior.DEFAULT
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
	How this fact's server answer combines with a locally-resolved one. See
	[AccessFactServerOverrideBehavior].

	@return string
]=]
function AccessFact.GetServerOverrideBehavior(self: AccessFact): string
	return self._serverOverrideBehavior
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
		-- Everything an author may hand back, named. A bare boolean or nil is normalised here so the merge
		-- only ever sees states, and an unlabelled nil can no longer reach it.
		Rx.map(function(value: any): AccessFactContribution
			if value == AccessFact.ABSTAIN then
				return AccessFact.contributionOfState(AccessFactContributionState.ABSTAIN)
			elseif AccessFact.isContribution(value) then
				return value
			end

			return AccessFact.contribution(value)
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
function AccessFact.GetDebugState(self: AccessFact): { [string]: any }
	return {
		factName = self._factName,
		priority = self._priority,
		source = self._source,
		serverOverrideBehavior = self._serverOverrideBehavior,
	}
end

--[[
	ValueObject.Mountable, unrolled. ValueObject only exposes this through Mount, which would mean owning
	a ValueObject per player just to read one value out of it.
]]
function AccessFact._toObservable(value: any): Observable.Observable<any>
	if value == AccessFact.ABSTAIN then
		return RxAccessStateUtils.ofStatic(AccessFact.ABSTAIN :: any)
	elseif Observable.isObservable(value) then
		return value :: any
	elseif typeof(value) == "Instance" then
		if ValueBaseUtils.isValueBase(value) then
			return RxValueBaseUtils.observeValue(value :: any) :: any
		end

		error(`[AccessFact] - Cannot resolve a fact from a {value.ClassName}`)
	elseif type(value) == "table" and ValueObject.isValueObject(value) then
		return (value :: any):Observe()
	elseif AccessFact.isContribution(value) then
		return RxAccessStateUtils.ofStatic(value :: any)
	elseif type(value) == "boolean" or value == nil then
		return RxAccessStateUtils.ofStatic(value :: boolean?)
	end

	error(`[AccessFact] - Cannot resolve a fact from a {typeof(value)}`)
end

return AccessFact
