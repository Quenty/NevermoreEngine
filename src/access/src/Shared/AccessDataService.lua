--!strict
--[=[
	Aggregates every [AccessFact] a game registers and answers every [AccessFeature] it gates against them.
	One place resolves the facts, one place applies the policy, and both realms read the same registry --
	so the menu, the storefront and the server's arrival gate reach one verdict instead of three that drift.

	Registration belongs in shared code, during `Init`:

	```lua
	function MyGameAccess:Init(serviceBag)
		local accessDataService = serviceBag:GetService(AccessDataService)

		self._maid:GiveTask(accessDataService:RegisterFact(MyGameFacts.OwnsGame))
		self._maid:GiveTask(accessDataService:RegisterFeature(MyGameFeatures.Chapters))
	end
	```

	## How a fact is decided

	Several layers may answer one fact. They are ordered by [AccessFactPriority], highest first, and **the
	first layer that contributes decides**. What it contributes may be `true`, `false`, or unresolved; a
	layer that abstains ([AccessFact.ABSTAIN]) is skipped entirely. If nothing contributes, the fact is
	unresolved.

	The merge does not return a value, it returns an [AccessFactReport] -- every layer, what each said, and
	which one won -- and the value features read is a field on it. The gate and the debug readout are
	therefore the same computation, so a readout can never explain a decision that was not the one made.

	## What is deliberately not here

	Facts are addressable by name so they can be inspected and overridden, but there is no `ObserveFact`.
	You can set a fact and you can look at one; you cannot subscribe to one and write your own rule at a
	call site. That asymmetry is what keeps every consumer reading the same verdict, which is the entire
	reason this is a package rather than four call sites that each decide for themselves.

	@class AccessDataService
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessDataServiceInterface = require("AccessDataServiceInterface")
local AccessFact = require("AccessFact")
local AccessFactNames = require("AccessFactNames")
local AccessFactPriority = require("AccessFactPriority")
local AccessFactServerOverrideBehavior = require("AccessFactServerOverrideBehavior")
local AccessFeature = require("AccessFeature")
local AccessReplicationState = require("AccessReplicationState")
local AccessReplicationStateUtils = require("AccessReplicationStateUtils")
local AccessStateUtils = require("AccessStateUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableMap = require("ObservableMap")
local OwnsGameAccessFact = require("OwnsGameAccessFact")
local PlayerIsAdminAccessFact = require("PlayerIsAdminAccessFact")
local Promise = require("Promise")
local Rx = require("Rx")
local RxAccessStateUtils = require("RxAccessStateUtils")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")
local ValueObject = require("ValueObject")
local WellKnownAccessFeatureNames = require("WellKnownAccessFeatureNames")

--[=[
	What one layer said, and whether it was the one that decided.

	`contributes` is the distinction the whole merge turns on: a layer that abstained said nothing and was
	skipped, whereas a layer that contributed `nil` said "nobody knows yet" and stopped the fall-through.

	@interface AccessFactLayerReport
	.source string
	.priority number
	.contributes boolean
	.value boolean? -- meaningful only when contributes
	.decided boolean -- true for the single layer that won
	@within AccessDataService
]=]
export type AccessFactLayerReport = {
	source: string,
	priority: number,
	contributes: boolean,
	value: boolean?,
	metadata: any?,
	decided: boolean,
}

--[=[
	One fact, fully explained: what features read, who decided it, and what every layer said. `layers` is
	ordered highest priority first, so it reads top-down the way the merge ran.

	@interface AccessFactReport
	.factName string
	.value boolean? -- what features read
	.decidedBy string? -- nil when every layer abstained
	.layers { AccessFactLayerReport }
	@within AccessDataService
]=]
export type AccessFactReport = {
	factName: string,
	value: boolean?,
	metadata: any?,
	decidedBy: string?,
	layers: { AccessFactLayerReport },
	-- What this realm worked out on its own, before the server's answer was applied. Kept separate so a
	-- readout can show both and say which won.
	localValue: boolean?,
	serverValue: boolean?,
	serverState: string,
	serverOverrideBehavior: string?,
	serverOverrode: boolean,
}

--[=[
	A verdict together with every fact it was reached from -- the whole answer to "why can this player not
	get in", in one place.

	@interface AccessFeatureReport
	.featureName string
	.state AccessState
	.facts { [string]: AccessFactReport }
	@within AccessDataService
]=]
export type AccessFeatureReport = {
	featureName: string,
	state: AccessStateUtils.AccessState,
	facts: { [string]: AccessFactReport },
}

-- An override is boxed because the value it carries may be nil -- forcing a fact to unresolved is a thing
-- you want to test, and a bare nil in the table would be indistinguishable from having no override at all.
type OverrideBox = { value: boolean? }
type OverrideState = { [string]: OverrideBox }

local EMPTY_OVERRIDE_STATE: OverrideState = {}
local OVERRIDE_SOURCE = "override"
local SERVER_SOURCE = "server"

local AccessDataService = {}
AccessDataService.ServiceName = "AccessDataService"

export type AccessDataService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_tieRealmService: any,
		-- Highest priority first, so the merge reads the array in order.
		-- Loosely typed for the same reason AccessFeature's fact list is: an array of a BaseObject-derived
		-- class does not unify with itself under the old solver, and the cascade reaches every caller.
		_layersByFactName: { [string]: { any } },
		_features: any,
		-- Weak keys, same as AccessFact's cache: a player who left takes their overrides with them without
		-- anything having to watch for it, which also keeps a PlayerMock working in tests.
		_overridesByPlayer: { [any]: any },
		-- True while the player is here. Weak-keyed like the rest: a departed player's entry is left false
		-- rather than removed, so anything asking about them afterwards completes at once instead of
		-- subscribing to a live stream that will never fire again.
		_presenceByPlayer: { [any]: any },
		_warnedMissingFacts: { [string]: boolean },
		-- What the server said, per player, per fact. Empty on the server itself.
		_serverValuesByPlayer: { [any]: any },
	},
	{} :: typeof({ __index = AccessDataService })
))

function AccessDataService.Init(self: AccessDataService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()
	self._tieRealmService = self._serviceBag:GetService(TieRealmService) :: any

	self._layersByFactName = {}
	self._features = self._maid:Add(ObservableMap.new()) :: any
	self._overridesByPlayer = setmetatable({}, { __mode = "k" }) :: any
	self._presenceByPlayer = setmetatable({}, { __mode = "k" }) :: any
	self._warnedMissingFacts = {}
	self._serverValuesByPlayer = setmetatable({}, { __mode = "k" }) :: any

	self:_registerBuiltInFacts()
end

-- Registered here rather than left to each game, so a console command and a feature can rely on these
-- names existing. All at AccessFactPriority.BUILT_IN, so a game that disagrees layers over them.
function AccessDataService._registerBuiltInFacts(self: AccessDataService): ()
	self._maid:GiveTask(self:RegisterFact(PlayerIsAdminAccessFact.new(self._serviceBag)))
	self._maid:GiveTask(self:RegisterFact(OwnsGameAccessFact.new(self._serviceBag)))

	-- Ships reading only the purchase. A game widens it with PushFactAllowsFeature rather than replacing
	-- it, so anything already gating on owns-game picks the new ways in up.
	self._maid:GiveTask(
		self:RegisterFeature(AccessFeature.anyOf(WellKnownAccessFeatureNames.OWNS_GAME, { AccessFactNames.OWNS_GAME }))
	)
end

function AccessDataService.Start(self: AccessDataService): ()
	-- Implemented on ReplicatedStorage because this is a singleton and ReplicatedStorage is the one
	-- adornee both realms already agree on -- no folder to create, no replication to wait for.
	self._maid:GiveTask(
		AccessDataServiceInterface:Implement(ReplicatedStorage, self :: any, self._tieRealmService:GetTieRealm())
	)
end

--[=[
	@param featureName string
	@return boolean
]=]
function AccessDataService.HasFeature(self: AccessDataService, featureName: string): boolean
	assert(type(featureName) == "string", "Bad featureName")

	return self._features:ContainsKey(featureName)
end

--[=[
	Whether the player may use this feature, addressed by name, as a plain boolean. Unresolved reads as
	false: a caller working from a string wants an answer, and failing closed is the safe half.

	Prefer the [AccessFeature] object where you have one -- a typo in a require is an error, a typo in a
	string is a feature that quietly denies.

	@param player Player
	@param featureName string
	@param subject any?
	@return boolean
]=]
function AccessDataService.IsFeatureAllowedByName(
	self: AccessDataService,
	player: Player,
	featureName: string,
	subject: any?
): boolean
	-- The LAST synchronous emission, not the first. Every access observable opens on unresolved before
	-- anything is looked up, so taking the first answer means always taking "nobody knows yet".
	local state = nil
	local subscription = self:ObserveFeatureAllowedStateByName(player, featureName, subject):Subscribe(function(value)
		state = value
	end)
	subscription:Destroy()

	return state ~= nil and AccessStateUtils.isAllowed(state)
end

--[=[
	@param player Player
	@param featureName string
	@param subject any?
	@return Observable<boolean>
]=]
function AccessDataService.ObserveIsFeatureAllowedByName(
	self: AccessDataService,
	player: Player,
	featureName: string,
	subject: any?
): Observable.Observable<boolean>
	return self:ObserveFeatureAllowedStateByName(player, featureName, subject):Pipe({
		Rx.map(AccessStateUtils.isAllowed) :: any,
		Rx.distinct() :: any,
	}) :: any
end

--[=[
	@param player Player
	@param featureName string
	@param subject any?
	@return Promise<boolean>
]=]
function AccessDataService.PromiseIsFeatureAllowedByName(
	self: AccessDataService,
	player: Player,
	featureName: string,
	subject: any?
): Promise.Promise<boolean>
	local feature =
		assert(self:GetFeature(featureName), `[AccessDataService] - No feature registered named {featureName}`)

	return self:PromiseFeature(player, feature, subject):Then(function(state)
		return AccessStateUtils.isAllowed(state)
	end) :: any
end

--[=[
	The full verdict for a feature addressed by name, so a caller can tell a refusal from a non-answer.

	@param player Player
	@param featureName string
	@param subject any?
	@return Observable<AccessState>
]=]
function AccessDataService.ObserveFeatureAllowedStateByName(
	self: AccessDataService,
	player: Player,
	featureName: string,
	subject: any?
): Observable.Observable<AccessStateUtils.AccessState>
	assert(type(featureName) == "string", "Bad featureName")

	local feature =
		assert(self:GetFeature(featureName), `[AccessDataService] - No feature registered named {featureName}`)

	return self:ObserveFeature(player, feature, subject)
end

--[=[
	Releases everything held for a player: their overrides, every fact layer's cached resolution, and any
	promise still waiting on a verdict for them.

	Driven by [AccessService] off `Players.PlayerRemoving` in a real game, and callable directly by a test
	or by anything holding a mock rather than a real Player -- so a session ends deterministically instead
	of waiting on the collector.

	Deliberately not wired to a player-observing utility in here: this service is shared, and every such
	utility depends on `playermock`, which this package already depends on for its own tests. Two paths to
	one module duplicates it in a built place and the loader can no longer resolve the name.

	@param player Player
]=]
function AccessDataService.TeardownPlayer(self: AccessDataService, player: Player): ()
	assert(player, "Bad player")

	-- Created if it does not exist yet: a player torn down before anyone asked about them must still read
	-- as gone, or the next question about them quietly starts a session for somebody who is not here.
	-- Fired first, so subscribers complete and promises reject while the state they read still exists.
	self:_getPresence(player).Value = false

	local overrides = self._overridesByPlayer[player]
	if overrides then
		overrides:Destroy()
		self._overridesByPlayer[player] = nil
	end

	for _, layers in self._layersByFactName do
		for _, layer in layers do
			layer:RemovePlayer(player)
		end
	end
end

--[=[
	Whether the player is still here. False forever once they have left.

	@param player Player
	@return Observable<boolean>
]=]
function AccessDataService.ObserveIsPlayerPresent(
	self: AccessDataService,
	player: Player
): Observable.Observable<boolean>
	assert(player, "Bad player")

	return self:_getPresence(player):Observe() :: any
end

-- Fires once, when the player goes. Already-departed players fire immediately, which is what makes a
-- subscription taken out after they left complete rather than hang.
function AccessDataService._observePlayerRemoving(self: AccessDataService, player: Player): any
	return self:_getPresence(player):Observe():Pipe({
		Rx.where(function(present: boolean)
			return not present
		end) :: any,
		Rx.first() :: any,
	})
end

function AccessDataService._getPresence(self: AccessDataService, player: Player): ValueObject.ValueObject<boolean>
	local existing = self._presenceByPlayer[player]
	if existing then
		return existing
	end

	local presence = ValueObject.new(true)
	self._presenceByPlayer[player] = presence

	return presence
end

--[=[
	Registers a layer of a fact.

	Two layers of the same fact must differ in both priority and source. Equal priorities would make the
	winner depend on registration order, and equal sources would leave a readout unable to say which layer
	decided -- both are refused at registration rather than discovered while someone is complaining.

	@param fact AccessFact
	@return () -> () -- Removes the layer
]=]
function AccessDataService.RegisterFact(self: AccessDataService, fact: AccessFact.AccessFact): () -> ()
	assert(AccessFact.isAccessFact(fact), "Bad fact")

	local factName = fact:GetFactName()
	local priority = fact:GetPriority()
	local source = fact:GetSource()

	assert(
		priority < AccessFactPriority.OVERRIDE,
		`[AccessDataService] - Fact {factName} cannot register at or above the override priority`
	)

	local layers = self._layersByFactName[factName]
	if not layers then
		layers = {}
		self._layersByFactName[factName] = layers
	end

	for _, existing in layers do
		assert(
			existing:GetPriority() ~= priority,
			`[AccessDataService] - Fact {factName} already has a layer at priority {priority}. Give this one a `
				.. `different AccessFactPriority so the winner does not depend on load order.`
		)
		assert(
			existing:GetSource() ~= source,
			`[AccessDataService] - Fact {factName} already has a layer sourced "{source}". Give this one a `
				.. `distinct options.source so a readout can name which layer decided.`
		)
	end

	fact:Init(self._serviceBag)

	table.insert(layers, fact)
	table.sort(layers, function(a, b)
		return a:GetPriority() > b:GetPriority()
	end)

	return function()
		local current = self._layersByFactName[factName]
		if not current then
			return
		end

		local index = table.find(current, fact)
		if index then
			table.remove(current, index)
		end

		if #current == 0 then
			self._layersByFactName[factName] = nil
		end
	end
end

--[=[
	Registers a fact from a value instead of a resolver -- one answer for every player.

	Prefer [AccessDataService.RegisterFact] with a resolver declared in shared code. Whoever calls this
	owns which realm has the fact, and a server-only call leaves the client with a fact that never
	resolves, which stalls every feature declaring it.

	@param factName string
	@param value ValueObject.Mountable<boolean?>
	@param options AccessFactOptions?
	@return () -> () -- Removes the layer
]=]
function AccessDataService.AddAccessFact(
	self: AccessDataService,
	factName: string,
	value: ValueObject.Mountable<boolean?>,
	options: AccessFact.AccessFactOptions?
): () -> ()
	local merged: AccessFact.AccessFactOptions = if options then table.clone(options) else {}
	merged.value = value

	return self:RegisterFact(AccessFact.new(factName, merged))
end

--[=[
	@param feature AccessFeature
	@return () -> () -- Removes the registration
]=]
function AccessDataService.RegisterFeature(self: AccessDataService, feature: AccessFeature.AccessFeature): () -> ()
	assert(AccessFeature.isAccessFeature(feature), "Bad feature")

	local featureName = feature:GetFeatureName()
	assert(
		not self._features:ContainsKey(featureName),
		`[AccessDataService] - Feature {featureName} is already registered`
	)

	return self._features:Set(featureName, feature)
end

--[=[
	The layers registered for a fact, highest priority first.

	@param factName string
	@return { AccessFact }
]=]
function AccessDataService.GetFactLayers(self: AccessDataService, factName: string): { AccessFact.AccessFact }
	assert(type(factName) == "string", "Bad factName")

	local layers = self._layersByFactName[factName]

	return if layers then table.clone(layers) else {}
end

--[=[
	@param factName string
	@return boolean
]=]
function AccessDataService.HasFact(self: AccessDataService, factName: string): boolean
	assert(type(factName) == "string", "Bad factName")

	return self._layersByFactName[factName] ~= nil
end

--[=[
	The feature registered under this name, for console commands and anything else working from a string.
	Code should hold the [AccessFeature] itself -- a typo in a require is an error, a typo in a string is a
	feature that quietly denies.

	@param featureName string
	@return AccessFeature?
]=]
function AccessDataService.GetFeature(self: AccessDataService, featureName: string): AccessFeature.AccessFeature?
	assert(type(featureName) == "string", "Bad featureName")

	return self._features:Get(featureName)
end

--[=[
	@return { string }
]=]
function AccessDataService.GetFactNames(self: AccessDataService): { string }
	local names = {}
	for factName in self._layersByFactName do
		table.insert(names, factName)
	end
	table.sort(names)

	return names
end

--[=[
	@return { string }
]=]
function AccessDataService.GetFeatureNames(self: AccessDataService): { string }
	local names = self._features:GetKeyList()
	table.sort(names)

	return names
end

--[=[
	Every registered feature name, live. Changes as a game registers more.

	@return Observable<{ string }>
]=]
function AccessDataService.ObserveFeatureNames(self: AccessDataService): Observable.Observable<{ string }>
	return self._features:ObserveKeyList() :: any
end

--[=[
	Whether the player may use this feature, live.

	Opens on unresolved rather than on nothing, so a consumer always has a state to render. Repeats of the
	same verdict are suppressed.

	@param player Player
	@param feature AccessFeature
	@param subject any? -- Passed to the feature's compute, for per-thing features
	@return Observable<AccessState>
]=]
function AccessDataService.ObserveFeature(
	self: AccessDataService,
	player: Player,
	feature: AccessFeature.AccessFeature,
	subject: any?
): Observable.Observable<AccessStateUtils.AccessState>
	assert(player, "Bad player")
	assert(AccessFeature.isAccessFeature(feature), "Bad feature")

	-- Re-derived when the feature's fact list changes, so a fact pushed onto a feature reaches everything
	-- already watching it rather than only whoever subscribes next.
	local observeFacts = feature:ObserveFactNames():Pipe({
		Rx.switchMap(function(factNames: { string })
			return self:_observeFactState(player, factNames)
		end) :: any,
	}) :: any

	return feature:ObserveCompute(observeFacts, subject):Pipe({
		RxAccessStateUtils.distinctState() :: any,
		RxAccessStateUtils.completeOn(self:_observePlayerRemoving(player)) :: any,
	}) :: any
end

--[=[
	Whether the player may use this feature, as a plain boolean.

	@param player Player
	@param feature AccessFeature
	@param subject any?
	@return Observable<boolean>
]=]
function AccessDataService.ObserveIsAllowed(
	self: AccessDataService,
	player: Player,
	feature: AccessFeature.AccessFeature,
	subject: any?
): Observable.Observable<boolean>
	return self:ObserveFeature(player, feature, subject):Pipe({
		Rx.map(AccessStateUtils.isAllowed) :: any,
		Rx.distinct() :: any,
	}) :: any
end

--[=[
	The verdict once it actually settles, skipping unresolved.

	GOTCHA: stays pending for as long as the answer stays unknown. That is deliberate -- a gate that
	resolved on a non-answer would be deciding by coin toss -- but it means a caller that must act within a
	bounded time has to impose its own timeout and decide what a timeout means for it.

	@param player Player
	@param feature AccessFeature
	@param subject any?
	@return Promise<AccessState>
]=]
function AccessDataService.PromiseFeature(
	self: AccessDataService,
	player: Player,
	feature: AccessFeature.AccessFeature,
	subject: any?
): Promise.Promise<AccessStateUtils.AccessState>
	local promise = Rx.toPromise(self:ObserveFeature(player, feature, subject):Pipe({
		Rx.where(function(state: AccessStateUtils.AccessState)
			return not AccessStateUtils.isUnresolved(state)
		end) :: any,
	}) :: any)

	-- Without this a gate waiting on a verdict that never settles outlives the session it was gating.
	-- Rejecting rather than resolving is deliberate: there is no verdict, and a caller that treated the
	-- absence of one as an answer is the bug this whole package exists to prevent.
	local subscription = self:_observePlayerRemoving(player):Subscribe(function()
		if promise:IsPending() then
			promise:Reject(`[AccessDataService] - Player left before {feature:GetFeatureName()} settled`)
		end
	end)
	promise:Finally(function()
		subscription:Destroy()
	end)

	return promise :: any
end

--[=[
	Forces a fact for this player, whatever its layers say. Pass nil to force unresolved, which is the
	state hardest to reproduce by hand and the one that strands players.

	Sits above every other layer, so an override never has to be reconciled against whatever a game added
	later. It shows up in a report as its own layer, with the layers it outranked still listed underneath
	-- so nobody mistakes an override left on for a genuine entitlement.

	Server-authoritative: a client that could set this could grant itself anything. Overrides are for
	tests and for console commands run by someone who already has permission.

	@param player Player
	@param factName string
	@param value boolean?
	@return () -> () -- Clears this override
]=]
function AccessDataService.SetFactOverride(
	self: AccessDataService,
	player: Player,
	factName: string,
	value: boolean?
): () -> ()
	assert(player, "Bad player")
	assert(type(factName) == "string", "Bad factName")
	assert(type(value) == "boolean" or value == nil, "Bad value")
	assert(self:HasFact(factName), `[AccessDataService] - No fact registered named {factName}`)

	local overrides = self:_getOverrides(player)
	local box: OverrideBox = { value = value }

	local state = table.clone(overrides.Value :: OverrideState)
	state[factName] = box
	overrides.Value = state

	return function()
		local current = overrides.Value :: OverrideState
		-- Only clear our own box; a later override for the same fact replaced this one and owns it now.
		if current[factName] ~= box then
			return
		end

		local without = table.clone(current)
		without[factName] = nil
		overrides.Value = without
	end
end

--[=[
	@param player Player
	@param factName string
]=]
function AccessDataService.ClearFactOverride(self: AccessDataService, player: Player, factName: string): ()
	assert(player, "Bad player")
	assert(type(factName) == "string", "Bad factName")

	local overrides = self._overridesByPlayer[player]
	if not overrides then
		return
	end

	local current = overrides.Value :: OverrideState
	if current[factName] == nil then
		return
	end

	local without = table.clone(current)
	without[factName] = nil
	overrides.Value = without
end

--[=[
	@param player Player
]=]
function AccessDataService.ClearFactOverrides(self: AccessDataService, player: Player): ()
	assert(player, "Bad player")

	local overrides = self._overridesByPlayer[player]
	if overrides then
		overrides.Value = EMPTY_OVERRIDE_STATE
	end
end

--[=[
	One fact, fully explained. The readout a console command renders, and the answer to "denied, but on
	account of what".

	@param player Player
	@param factName string
	@return Observable<AccessFactReport>
]=]
function AccessDataService.ObserveFactReport(
	self: AccessDataService,
	player: Player,
	factName: string
): Observable.Observable<AccessFactReport>
	assert(player, "Bad player")
	assert(
		self:HasFact(factName) or self:_hasServerFactValue(player, factName),
		`[AccessDataService] - No fact named {factName} is registered here and none has been replicated. `
			.. `Register it in shared code, or let the server replicate it.`
	)

	-- May legitimately be empty: a fact the client cannot compute is registered only on the server, and
	-- reaches this realm purely as a replicated value.
	local layers: { any } = self._layersByFactName[factName] or {}
	local sources: { [string]: any } = {
		overrides = self:_observeOverrides(player),
		serverValue = self:_observeServerFactValue(player, factName),
	}

	for index, layer in layers do
		sources[tostring(index)] = layer:ObserveForPlayer(player)
	end

	return Rx.combineLatest(sources):Pipe({
		RxAccessStateUtils.completeOn(self:_observePlayerRemoving(player)) :: any,
		Rx.map(function(latest: { [string]: any }): AccessFactReport
			local overrides = (latest.overrides or EMPTY_OVERRIDE_STATE) :: OverrideState

			local contributions = {
				{
					source = OVERRIDE_SOURCE,
					priority = AccessFactPriority.OVERRIDE,
					contribution = overrides[factName],
				},
			}
			for index, layer in layers do
				table.insert(contributions, {
					source = layer:GetSource(),
					priority = layer:GetPriority(),
					contribution = latest[tostring(index)],
				})
			end

			local report = AccessDataService._mergeContributions(factName, contributions)
			-- No layers means nothing local declared a behavior; the default applies, and rule 2 in
			-- AccessFactServerOverrideBehavior.combine makes the server's value decide anyway.
			local behavior = if layers[1] then layers[1]:GetServerOverrideBehavior() else nil

			return AccessDataService._applyServerValue(report, latest.serverValue, behavior)
		end) :: any,
	}) :: any
end

--[=[
	Folds the server's replicated answer into a locally-merged report, per the fact's
	[AccessFactServerOverrideBehavior]. The local answer is kept alongside rather than replaced, so a
	readout can show what this realm thought and what the server said.

	@param report AccessFactReport
	@param serverValue boolean?
	@param behavior string?
	@return AccessFactReport
	@private
]=]
function AccessDataService._applyServerValue(
	report: AccessFactReport,
	serverEntry: { value: boolean?, abstained: boolean? }?,
	behavior: string?
): AccessFactReport
	local localValue = report.value
	local serverValue = if serverEntry then serverEntry.value else nil
	local serverState = AccessReplicationStateUtils.fromEntry(serverEntry)
	local combined = AccessFactServerOverrideBehavior.combine(localValue, serverValue, serverState, behavior)

	report.localValue = localValue
	report.serverValue = serverValue
	report.serverState = serverState
	report.serverOverrideBehavior = behavior or AccessFactServerOverrideBehavior.DEFAULT
	report.serverOverrode = combined ~= localValue
	report.value = combined

	if report.serverOverrode then
		report.decidedBy = SERVER_SOURCE
	end

	return report
end

--[=[
	Every registered fact for this player, fully explained.

	@param player Player
	@return Observable<{ [string]: AccessFactReport }>
]=]
function AccessDataService.ObserveFactReports(
	self: AccessDataService,
	player: Player
): Observable.Observable<{ [string]: AccessFactReport }>
	assert(player, "Bad player")

	local sources: { [string]: any } = {}
	for factName in self._layersByFactName do
		sources[factName] = self:ObserveFactReport(player, factName)
	end

	return Rx.combineLatest(sources) :: any
end

--[=[
	A feature's verdict together with every fact it was reached from -- the whole answer to a complaint,
	in one subscription.

	@param player Player
	@param feature AccessFeature
	@param subject any?
	@return Observable<AccessFeatureReport>
]=]
function AccessDataService.ObserveFeatureReport(
	self: AccessDataService,
	player: Player,
	feature: AccessFeature.AccessFeature,
	subject: any?
): Observable.Observable<AccessFeatureReport>
	assert(AccessFeature.isAccessFeature(feature), "Bad feature")

	local factSources: { [string]: any } = {}
	for _, factName in feature:GetFactNames() do
		factSources[factName] = self:ObserveFactReport(player, factName)
	end

	return Rx.combineLatest({
		state = self:ObserveFeature(player, feature, subject),
		facts = Rx.combineLatest(factSources),
	}):Pipe({
		Rx.map(function(latest: any): AccessFeatureReport
			return {
				featureName = feature:GetFeatureName(),
				state = latest.state,
				facts = latest.facts or {},
			}
		end) :: any,
	}) :: any
end

--[=[
	Everything registered, as plain tables. Player-independent -- for "what does this game gate, and what
	answers it", which is the question you have before you have a player to ask about.

	Live per-player state is [AccessDataService.ObserveFactReports], and the console renders both.

	@return { facts: { [string]: { { factName: string, priority: number, source: string } } }, features: { [string]: { featureName: string, facts: { string } } } }
]=]
function AccessDataService.GetDebugState(
	self: AccessDataService
): { facts: { [string]: any }, features: { [string]: any } }
	local facts = {}
	for factName, layers in self._layersByFactName do
		local described = {}
		for _, layer in layers do
			table.insert(described, layer:GetDebugState())
		end
		facts[factName] = described
	end

	local features = {}
	for _, featureName in self._features:GetKeyList() do
		features[featureName] = self._features:Get(featureName):GetDebugState()
	end

	return { facts = facts, features = features }
end

--[=[
	The merge, as a pure function: layers highest priority first, the first that contributes decides.

	@param factName string
	@param contributions { { source: string, priority: number, contribution: AccessFactContribution } }
	@return AccessFactReport
	@private
]=]
function AccessDataService._mergeContributions(
	factName: string,
	contributions: { { source: string, priority: number, contribution: any } }
): AccessFactReport
	local report: AccessFactReport = {
		factName = factName,
		value = nil,
		metadata = nil,
		decidedBy = nil,
		layers = {},
		-- Filled in by _applyServerValue; declared here so the shape is complete from the start rather
		-- than growing fields partway through the pipeline.
		localValue = nil,
		serverValue = nil,
		serverState = AccessReplicationState.NOT_YET_ARRIVED,
		serverOverrideBehavior = nil,
		serverOverrode = false,
	}

	local alreadyDecided = false
	for _, entry in contributions do
		local contributes = entry.contribution ~= nil
		local decided = contributes and not alreadyDecided

		if decided then
			alreadyDecided = true
			report.value = entry.contribution.value
			-- Attribution follows the answer: the report carries the deciding layer's metadata, because
			-- the layers it outranked did not decide anything and their reasons would mislead.
			report.metadata = entry.contribution.metadata
			report.decidedBy = entry.source
		end

		table.insert(report.layers, {
			source = entry.source,
			priority = entry.priority,
			contributes = contributes,
			value = if contributes then entry.contribution.value else nil,
			metadata = if contributes then entry.contribution.metadata else nil,
			decided = decided,
		})
	end

	return report
end

-- The facts a feature declared, folded into one table. Facts it did not declare are absent, so a
-- mechanism that is broken or slow only stalls the features that actually asked about it.
function AccessDataService._observeFactState(
	self: AccessDataService,
	player: Player,
	factNames: { string }
): Observable.Observable<AccessStateUtils.AccessFactState>
	if #factNames == 0 then
		return Rx.of({} :: AccessStateUtils.AccessFactState) :: any
	end

	local sources: { [string]: any } = {}
	for _, factName in factNames do
		if not self:HasFact(factName) then
			-- No local layer can answer it, so this realm follows the replicated value alone. Observed
			-- rather than sampled: replication may well arrive after whatever is watching subscribed, and
			-- a value pinned at subscribe time would leave the feature unresolved forever.
			--
			-- Warned about only when nothing has been replicated either, because then genuinely nothing
			-- can answer it -- usually a fact registered in one realm and not the other.
			if not self:_hasServerFactValue(player, factName) then
				self:_warnMissingFactOnce(factName)
			end

			sources[factName] = self:_observeServerFactValue(player, factName):Pipe({
				Rx.map(function(entry: any)
					return if entry then entry.value else nil
				end) :: any,
			})
		else
			sources[factName] = self:ObserveFactReport(player, factName):Pipe({
				Rx.map(function(report: AccessFactReport)
					return report.value
				end) :: any,
				Rx.distinct() :: any,
			})
		end
	end

	return Rx.combineLatest(sources) :: any
end

-- Once per name, because a feature re-derives its fact list on every change and would otherwise warn on
-- a loop. The registry itself is the real readout -- see GetDebugState and access-facts.
function AccessDataService._warnMissingFactOnce(self: AccessDataService, factName: string): ()
	if self._warnedMissingFacts[factName] then
		return
	end
	self._warnedMissingFacts[factName] = true

	warn(
		`[AccessDataService] - Feature reads fact "{factName}", which is not registered in this realm. `
			.. `It will read as unresolved. Register the fact in shared code so both realms can answer it.`
	)
end

--[=[
	Records what the server says a fact reads as for this player. Called by the client's replication
	receiver; the server itself never calls it.

	Replication is unconditional -- every fact's server answer is sent -- and what a client *does* with
	it is the fact's [AccessFactServerOverrideBehavior]. Splitting it that way means a fact can never
	accidentally not replicate, only decline to be overridden by what arrived.

	@param player Player
	@param factName string
	@param value boolean?
]=]
function AccessDataService.SetServerFactValue(
	self: AccessDataService,
	player: Player,
	factName: string,
	value: boolean?,
	abstained: boolean?
): ()
	assert(player, "Bad player")
	assert(type(factName) == "string", "Bad factName")
	assert(type(value) == "boolean" or value == nil, "Bad value")

	local store = self._serverValuesByPlayer[player]
	if not store then
		store = ValueObject.new({})
		self._serverValuesByPlayer[player] = store
	end

	local next = table.clone(store.Value)
	-- Boxed, so "the server says unresolved" is distinguishable from "the server has not said anything",
	-- which is the difference between overriding and not.
	next[factName] = { value = value, abstained = abstained }
	store.Value = next
end

-- Whether the server has ever said anything about this fact for this player. Distinct from the value
-- being nil, which is the server actively saying "unresolved".
function AccessDataService._hasServerFactValue(self: AccessDataService, player: Player, factName: string): boolean
	local store = self._serverValuesByPlayer[player]

	return store ~= nil and (store.Value :: any)[factName] ~= nil
end

function AccessDataService._observeServerFactValue(
	self: AccessDataService,
	player: Player,
	factName: string
): Observable.Observable<boolean?>
	local store = self._serverValuesByPlayer[player]
	if not store then
		store = ValueObject.new({})
		self._serverValuesByPlayer[player] = store
	end

	return store:Observe():Pipe({
		Rx.map(function(values: { [string]: any })
			-- The whole entry, not its value: "no entry" and "an entry whose value is nil" are different
			-- states and the combine needs to tell them apart.
			return values[factName]
		end) :: any,
		Rx.distinct() :: any,
	}) :: any
end

function AccessDataService._observeOverrides(
	self: AccessDataService,
	player: Player
): Observable.Observable<OverrideState>
	return self:_getOverrides(player):Observe() :: any
end

-- Created on first use rather than on join: a game with no overrides in play allocates nothing, and there
-- is no player lifecycle to hook. Not held by the maid on purpose -- a strong reference here would defeat
-- the weak keys and keep every player who ever joined alive for the session.
function AccessDataService._getOverrides(
	self: AccessDataService,
	player: Player
): ValueObject.ValueObject<OverrideState>
	local existing = self._overridesByPlayer[player]
	if existing then
		return existing
	end

	local overrides = ValueObject.new(EMPTY_OVERRIDE_STATE :: any)
	self._overridesByPlayer[player] = overrides

	return overrides
end

function AccessDataService.Destroy(self: AccessDataService): ()
	for _, overrides in self._overridesByPlayer do
		overrides:Destroy()
	end
	table.clear(self._overridesByPlayer :: any)
	table.clear(self._layersByFactName :: any)

	self._maid:DoCleaning()
end

return AccessDataService
