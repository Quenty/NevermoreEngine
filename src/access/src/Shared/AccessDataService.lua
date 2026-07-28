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
local AccessFactContributionState = require("AccessFactContributionState")
local AccessFactContributionStateUtils = require("AccessFactContributionStateUtils")
local AccessFactNames = require("AccessFactNames")
local AccessFactPriority = require("AccessFactPriority")
local AccessFactServerOverrideBehavior = require("AccessFactServerOverrideBehavior")
local AccessFeature = require("AccessFeature")
local AccessReplicationState = require("AccessReplicationState")
local AccessReplicationStateUtils = require("AccessReplicationStateUtils")
local AccessStateUtils = require("AccessStateUtils")
local JSONAttributeValue = require("JSONAttributeValue")
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
local TieRealms = require("TieRealms")
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
	state: string,
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
	state: string,
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
	-- The feature's declared non-fact inputs, resolved for this subject. Empty for a feature with none.
	context: { [string]: any },
	-- The whole verdict of each feature this one reads, so a refusal inherited from another feature keeps
	-- the reason it was refused for.
	features: { [string]: AccessStateUtils.AccessState },
}

-- An override is boxed because the value it carries may be nil -- forcing a fact to unresolved is a thing
-- you want to test, and a bare nil in the table would be indistinguishable from having no override at all.
type OverrideBox = { value: boolean? }
type OverrideState = { [string]: OverrideBox }

local EMPTY_OVERRIDE_STATE: OverrideState = {}
local OVERRIDE_SOURCE = "override"
local REPLICATED_SOURCE = "replicated"
local FEATURE_FACT_NAMES_ATTRIBUTE = "AccessFeatureFactNames"

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
		-- The registered fact names, live. Kept beside _layersByFactName rather than derived from it,
		-- because anything reading "every fact" has to notice one registered after it subscribed.
		_factNames: any,
		-- What the server said, per player, per fact. Empty on the server itself.
		_serverValuesByPlayer: { [any]: any },
		-- The overrides the server has in force, per player. Empty on the server itself, which holds its
		-- own in _overridesByPlayer.
		_serverOverridesByPlayer: { [any]: any },
		-- The fact names the server says each feature reads. Empty on the server itself.
		_replicatedFeatureFactNames: { [string]: { string } },
		-- Removers for the pushes this realm made on the server's behalf, so reconciling can take back
		-- exactly what it added and nothing a game pushed itself.
		_pushedFeatureFactRemovers: { [string]: { [string]: () -> () } },
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
	self._factNames = self._maid:Add(ValueObject.new({})) :: any
	self._serverValuesByPlayer = setmetatable({}, { __mode = "k" }) :: any
	self._serverOverridesByPlayer = setmetatable({}, { __mode = "k" }) :: any
	self._replicatedFeatureFactNames = {}
	self._pushedFeatureFactRemovers = {}

	self:_registerBuiltInFacts()
end

--[[
	Registered here rather than left to each game, so a command or a feature can rely on these names
	existing. All at AccessFactPriority.BUILT_IN, so a game that disagrees layers over them.
]]
function AccessDataService._registerBuiltInFacts(self: AccessDataService): ()
	self._maid:GiveTask(self:RegisterFact(self._maid:Add(PlayerIsAdminAccessFact.new(self._serviceBag))))
	self._maid:GiveTask(self:RegisterFact(self._maid:Add(OwnsGameAccessFact.new(self._serviceBag))))

	-- Ships reading only the purchase. A game widens it with PushFactAllowsFeature rather than replacing
	-- it, so anything already gating on owns-game picks the new ways in up.
	self._maid:GiveTask(
		self:RegisterFeature(
			self._maid:Add(AccessFeature.anyOf(WellKnownAccessFeatureNames.OWNS_GAME, { AccessFactNames.OWNS_GAME }))
		)
	)
end

function AccessDataService.Start(self: AccessDataService): ()
	local tieRealm = self._tieRealmService:GetTieRealm()

	-- Reconciles in either realm on a registry change: the payload is empty on the server, so this costs
	-- nothing there, and on the client a feature registered after the payload landed still picks up its
	-- pushes. Either signal may arrive first and neither order is ours to control.
	self._maid:GiveTask(self._features:ObserveKeyList():Subscribe(function()
		self:_reconcileReplicatedFeatureFacts()
	end))

	-- Branching on the tie realm rather than on RunService, for the same reason the tie itself does: it is
	-- the one realm answer a service bag can be told, which is what lets both halves be booted together
	-- and actually exercised against each other.
	if tieRealm == TieRealms.CLIENT then
		self:_consumeReplicatedFeatureFactNames()
	else
		self:_replicateFeatureFactNames()
	end

	-- Last, and deliberately: implementing a client-side tie waits for the server's implementation, and
	-- replication must not be sitting behind that. A realm that never got its tie up should still be
	-- reading the facts and features the other realm published.
	--
	-- On ReplicatedStorage because this is a singleton and ReplicatedStorage is the one adornee both
	-- realms already agree on -- no folder to create, nothing to find.
	self._maid:GiveTask(
		AccessDataServiceInterface:Implement(ReplicatedStorage, self:_buildTieImplementer(tieRealm), tieRealm)
	)
end

--[[
	Publishes what every registered feature reads, so a push made only on the server reaches the client.

	A fact's *value* replicates per player; which facts a feature reads is game-wide, so it goes on
	ReplicatedStorage rather than on a Player. Rebuilt wholesale rather than diffed: there are few
	features, and a half-applied composition would have a client gating on a rule the server does not have.
]]
function AccessDataService._replicateFeatureFactNames(self: AccessDataService): ()
	local replicated: any = JSONAttributeValue.new(ReplicatedStorage, FEATURE_FACT_NAMES_ATTRIBUTE, {})
	local lastPublished: string? = nil

	-- Cleared when this service goes, because the attribute outlives the object that wrote it and the next
	-- service up would read a dead one's composition as current.
	--
	-- Only if what is there is still ours, though. The attribute is one slot on ReplicatedStorage and
	-- nothing stops another live service from having published since -- clearing unconditionally would
	-- take down a composition somebody is currently gating on, which is worse than the stale payload this
	-- is here to prevent.
	self._maid:GiveTask(function()
		if lastPublished ~= nil and ReplicatedStorage:GetAttribute(FEATURE_FACT_NAMES_ATTRIBUTE) == lastPublished then
			replicated.Value = nil
		end
	end)

	local function publish()
		local payload = {}
		for _, featureName in self:GetFeatureNames() do
			local feature = self._features:Get(featureName)
			if feature then
				payload[featureName] = feature:GetFactNames()
			end
		end

		replicated.Value = payload
		lastPublished = ReplicatedStorage:GetAttribute(FEATURE_FACT_NAMES_ATTRIBUTE)
	end

	self._maid:GiveTask(self._features:ObserveKeyList():Subscribe(function(featureNames: { string })
		local maid = Maid.new()

		for _, featureName in featureNames do
			local feature = self._features:Get(featureName)
			if feature then
				maid:GiveTask(feature:ObserveFactNames():Subscribe(publish))
			end
		end

		self._maid._featureFactNamesMaid = maid
	end))
end

function AccessDataService._consumeReplicatedFeatureFactNames(self: AccessDataService): ()
	local replicated: any = JSONAttributeValue.new(ReplicatedStorage, FEATURE_FACT_NAMES_ATTRIBUTE, {})

	self._maid:GiveTask(replicated:Observe():Subscribe(function(payload: any)
		self:SetReplicatedFeatureFactNames(payload or {})
	end))
end

--[=[
	Applies what the server says each feature reads. The entry point the client's replication arrives
	through, and the seam a test drives directly.

	Facts named here need no resolver in this realm -- an unregistered fact reads as unresolved locally and
	takes its answer from the per-player replication, which is the whole point of being told about it.

	@param payload { [string]: { string } }
]=]
function AccessDataService.SetReplicatedFeatureFactNames(self: AccessDataService, payload: { [string]: { string } }): ()
	assert(type(payload) == "table", "Bad payload")

	self._replicatedFeatureFactNames = payload
	self:_reconcileReplicatedFeatureFacts()
end

--[[
	Only ever takes back its own pushes. A game that pushed a fact onto a feature in shared code keeps it,
	whatever the server happens to be saying -- replication widens a feature here, it does not own it.
]]
function AccessDataService._reconcileReplicatedFeatureFacts(self: AccessDataService): ()
	local payload = self._replicatedFeatureFactNames

	for featureName, pushed in self._pushedFeatureFactRemovers do
		local wanted = payload[featureName]

		for factName, remove in pushed do
			if not (wanted and table.find(wanted, factName)) then
				pushed[factName] = nil
				remove()
			end
		end
	end

	for featureName, factNames in payload do
		local feature = self._features:Get(featureName)
		if not feature then
			continue
		end

		local pushed = self._pushedFeatureFactRemovers[featureName]
		if not pushed then
			pushed = {}
			self._pushedFeatureFactRemovers[featureName] = pushed
		end

		local already = feature:GetFactNames()
		for _, factName in factNames do
			if not pushed[factName] and not table.find(already, factName) then
				pushed[factName] = feature:PushFactNameAllowsFeature(factName)
			end
		end
	end
end

--[[
	This class is shared, but the tie declares the override setters SERVER-only and refuses a client
	implementation that *carries* one -- it filters nothing, it errors. So the implementer is built for the
	realm the tie is being told about rather than being `self`: on a client the setters are simply not
	there.

	GOTCHA: built from that realm and not from [RunService]. They differ wherever a bag is told its realm
	-- a test booting both halves in one DataModel is the whole reason [TieRealmService] exists -- and
	getting it from RunService there means a client implementation carrying server members, which throws
	inside `ServiceBag:Start`'s `task.spawn` and is therefore silent.
]]
function AccessDataService._buildTieImplementer(self: AccessDataService, tieRealm: string): any
	local implementer = {}

	local shared = {
		"GetFactNames",
		"GetFeatureNames",
		"HasFact",
		"HasFeature",
		"IsFeatureAllowedByName",
		"ObserveIsFeatureAllowedByName",
		"PromiseIsFeatureAllowedByName",
		"ObserveFeatureAllowedStateByName",
		"ObserveFactReport",
		"ObserveFactReports",
		"ObserveIsPlayerPresent",
	}
	local serverOnly = {
		"SetFactOverride",
		"ClearFactOverride",
		"ClearFactOverrides",
		"TeardownPlayer",
	}

	--[[
		Declared with a receiver: the tie invokes members method-style, so the first argument is the
		implementer and the real arguments follow it.
	]]
	local function delegate(methodName: string)
		implementer[methodName] = function(_implementer, ...)
			return (self :: any)[methodName](self, ...)
		end
	end

	for _, methodName in shared do
		delegate(methodName)
	end

	if tieRealm ~= TieRealms.CLIENT then
		for _, methodName in serverOnly do
			delegate(methodName)
		end
	end

	return implementer
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

	for _, byPlayer in { self._overridesByPlayer, self._serverOverridesByPlayer } do
		local overrides = byPlayer[player]
		if overrides then
			overrides:Destroy()
			byPlayer[player] = nil
		end
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

--[[
	Fires once, when the player goes. Already-departed players fire immediately, which is what makes a
	subscription taken out after they left complete rather than hang.
]]
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

	Registering does not take ownership. A fact has a lifetime of its own, so give it to a maid at the
	point you make it and the disposer to a maid too.

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
	self:_refreshFactNames()

	local unregistered = false
	local function unregister()
		if unregistered then
			return
		end
		unregistered = true

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

		self:_refreshFactNames()
	end

	-- A destroyed fact must never stay a registered layer. One maid commonly holds both the fact and this
	-- disposer, and DoCleaning runs its tasks in no particular order -- so relying on the caller to
	-- unregister first is relying on luck. BaseObject runs the object's own maid *before* nilling its
	-- metatable, so hooking it here takes the layer out while it is still a usable object; a moment later
	-- every method call on it would fail instead.
	fact._maid:GiveTask(unregister)

	return unregister
end

--[[
	Only assigns when the set actually changed.

	GetFactNames builds a fresh table every call and ValueObject compares by identity, so assigning
	unconditionally fires on every registration -- including a second *layer* of a fact already present,
	which changes no names at all. Anything switchMapping over this then drops its shareReplay, and every
	resolver for every player re-runs: the marketplace lookups, the permission lookups, and a flap through
	all-unresolved that replicates to every client on the way.
]]
function AccessDataService._refreshFactNames(self: AccessDataService): ()
	if not self._factNames then
		return
	end

	local names = self:GetFactNames()
	local current = self._factNames.Value

	if current and #current == #names then
		local same = true
		for index, name in names do
			if current[index] ~= name then
				same = false
				break
			end
		end

		if same then
			return
		end
	end

	self._factNames.Value = names
end

--[=[
	Registers a fact from a value instead of a resolver -- one answer for every player.

	Prefer [AccessDataService.RegisterFact] with a resolver declared in shared code. Whoever calls this
	owns which realm has the fact, and a server-only call leaves the client with a fact that never
	resolves, which stalls every feature declaring it.

	Unlike [AccessDataService.RegisterFact], the returned disposer also destroys the fact: it is made here
	and never handed out, so there is no call site that could own it.

	@param factName string
	@param value ValueObject.Mountable<boolean?>
	@param options AccessFactOptions?
	@return () -> () -- Removes the layer and destroys the fact
]=]
function AccessDataService.AddAccessFact(
	self: AccessDataService,
	factName: string,
	value: ValueObject.Mountable<boolean?>,
	options: AccessFact.AccessFactOptions?
): () -> ()
	local merged: AccessFact.AccessFactOptions = if options then table.clone(options) else {}
	merged.value = value

	local fact = AccessFact.new(factName, merged)
	local unregister = self:RegisterFact(fact)

	return function()
		unregister()
		fact:Destroy()
	end
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

	local remove = self._features:Set(featureName, feature)
	local unregistered = false

	local function unregister()
		if unregistered then
			return
		end
		unregistered = true

		-- The removers held here close over *this* feature object. Once it is gone they have nothing to act
		-- on, and leaving them keyed by name means a feature later registered under the same name is skipped
		-- as already-pushed and silently gates on the narrower rule.
		self._pushedFeatureFactRemovers[featureName] = nil

		remove()
	end

	-- Same reason as a fact's: a destroyed feature left in the registry is one every reader would call
	-- methods on. See RegisterFact.
	feature._maid:GiveTask(unregister)

	return unregister
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
	-- Refused rather than answered. Asking a per-thing gate about no thing has no meaning, and the compute
	-- behind it was written expecting the thing -- which is how the flag's absence crashed a purchase gate
	-- in the first place. Skipping it in the tracker was never enough on its own: a direct call, a console
	-- command with the argument left off, or a policy all reach here too.
	assert(
		not (feature:RequiresSubject() and subject == nil),
		`[AccessDataService] - Feature {feature:GetFeatureName()} requires a subject. Pass the thing being `
			.. `asked about -- a world index, a chapter -- rather than nothing.`
	)

	-- Re-derived when the feature's fact list changes, so a fact pushed onto a feature reaches everything
	-- already watching it rather than only whoever subscribes next.
	local observeFacts = feature:ObserveFactNames():Pipe({
		Rx.switchMap(function(factNames: { string })
			return self:_observeFactState(player, factNames)
		end) :: any,
	}) :: any

	return feature
		:ObserveCompute(observeFacts, subject, {
			observeFeatures = self:_observeFeatureInputs(player, feature, subject),
			player = player,
		})
		:Pipe({
			RxAccessStateUtils.distinctState() :: any,
			RxAccessStateUtils.completeOn(self:_observePlayerRemoving(player)) :: any,
		}) :: any
end

--[[
	The whole verdict of each feature this one declared, keyed by name.

	Whole verdicts rather than booleans: a feature reading another through [FeatureAccessFact] gets a
	yes/no and loses why, and "refused because bought access is switched off" is a different thing to tell
	somebody than "refused because they do not own it".
]]
function AccessDataService._observeFeatureInputs(
	self: AccessDataService,
	player: Player,
	feature: AccessFeature.AccessFeature,
	subject: any?
): Observable.Observable<{ [string]: AccessStateUtils.AccessState }>
	local sources: { [string]: any } = {}
	for _, input in feature:GetFeatureInputs() do
		sources[input:GetFeatureName()] = self:ObserveFeature(player, input, subject)
	end

	if next(sources) == nil then
		return RxAccessStateUtils.ofStatic({}) :: any
	end

	return Rx.combineLatest(sources) :: any
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
		if not current then
			-- Teardown order is not ours to control: one maid may hold both this disposer and the service
			-- bag, and lifting an override off a player who is already gone is a no-op, not an error.
			return
		end

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

	-- Warned about, not thrown on, and for the same reason _observeFactState tolerates it: a feature
	-- widened by a server-only push names facts this realm may never have heard of, and the readout that
	-- would explain that is the last thing that should be the one to die.
	if not (self:HasFact(factName) or self:_hasServerFactValue(player, factName)) then
		self:_warnMissingFactOnce(factName)
	end

	-- May legitimately be empty: a fact the client cannot compute is registered only on the server, and
	-- reaches this realm purely as a replicated value.
	local layers: { any } = self._layersByFactName[factName] or {}
	local sources: { [string]: any } = {
		overrides = self:_observeOverrides(player),
		replicatedOverrides = self:_observeReplicatedOverrides(player),
		serverValue = self:_observeServerFactValue(player, factName),
	}

	for index, layer in layers do
		sources[tostring(index)] = layer:ObserveForPlayer(player)
	end

	return Rx.combineLatest(sources):Pipe({
		RxAccessStateUtils.completeOn(self:_observePlayerRemoving(player)) :: any,
		Rx.map(function(latest: { [string]: any }): AccessFactReport
			local overrides = (latest.overrides or EMPTY_OVERRIDE_STATE) :: OverrideState
			local replicatedOverrides = (latest.replicatedOverrides or EMPTY_OVERRIDE_STATE) :: OverrideState
			local behavior = if layers[1] then layers[1]:GetServerOverrideBehavior() else nil

			-- An override set in this realm shadows one the server sent, so a local investigation is not
			-- fighting a console session somebody left running elsewhere.
			local overrideBox = overrides[factName]
			local overrideCameFromServer = overrideBox == nil and replicatedOverrides[factName] ~= nil
			overrideBox = overrideBox or replicatedOverrides[factName]

			-- Override sits above everything, and abstains when nothing is set rather than being absent:
			-- every row in a report is a layer, so a readout shows what it would have done.
			local contributions: { any } = {
				{
					source = OVERRIDE_SOURCE,
					priority = AccessFactPriority.OVERRIDE,
					terminating = true,
					contribution = if overrideBox
						then AccessFact.contribution(
							overrideBox.value,
							-- Named in the readout, because "I cleared that override and it is still set"
							-- is otherwise a very confusing half hour.
							if overrideCameFromServer then { replicated = true } else nil
						)
						else AccessFact.contributionOfState(AccessFactContributionState.ABSTAIN),
				},
			}

			-- What the server replicated, as a layer like any other. Its position is what the fact's
			-- AccessFactServerOverrideBehavior actually means: "override on allow only" is a layer that
			-- sits above the local ones when it says yes and below them when it does not.
			local replicated = AccessDataService._replicatedContribution(latest.serverValue, behavior)
			if replicated.aboveLocal then
				table.insert(contributions, replicated.entry)
			end

			for index, layer in layers do
				table.insert(
					contributions,
					{
						source = layer:GetSource(),
						priority = layer:GetPriority(),
						terminating = false,
						contribution = latest[tostring(index)],
					} :: any
				)
			end

			if not replicated.aboveLocal then
				table.insert(contributions, replicated.entry)
			end

			local report = AccessDataService._mergeContributions(factName, contributions)
			report.serverState = AccessReplicationStateUtils.fromEntry(latest.serverValue)
			report.serverValue = if latest.serverValue then latest.serverValue.value else nil
			report.serverOverrideBehavior = behavior or AccessFactServerOverrideBehavior.DEFAULT
			report.serverOverrode = report.decidedBy == REPLICATED_SOURCE

			return report
		end) :: any,
	}) :: any
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

	-- Rebuilt when the registry changes, not snapshotted at subscribe: a fact registered after a player
	-- joined would otherwise never reach anything reading "every fact" -- including the binder that
	-- replicates them, which is how a late-registered fact silently never arrives on the client.
	return self:ObserveFactNames():Pipe({
		Rx.switchMap(function(factNames: { string })
			local sources: { [string]: any } = {}
			for _, factName in factNames do
				sources[factName] = self:ObserveFactReport(player, factName)
			end

			return Rx.combineLatest(sources)
		end) :: any,
	}) :: any
end

--[=[
	The registered fact names, live. Emits again whenever a layer is registered or removed.

	@return Observable<{ string }>
]=]
function AccessDataService.ObserveFactNames(self: AccessDataService): Observable.Observable<{ string }>
	return self._factNames:Observe() :: any
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
		-- Reported beside the facts, because for a per-thing gate the answer is as often "this egg is
		-- already collected" as it is "this player does not own the game", and only one of those was
		-- visible before.
		context = feature:ObserveContext(subject),
		features = self:_observeFeatureInputs(player, feature, subject),
	}):Pipe({
		Rx.map(function(latest: any): AccessFeatureReport
			return {
				featureName = feature:GetFeatureName(),
				state = latest.state,
				facts = latest.facts or {},
				context = latest.context or {},
				features = latest.features or {},
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

--[[
	The replicated answer as a layer, plus where it sits relative to the local ones. That position is the
	whole of what a behavior means: a layer above the locals wins when it speaks, one below only answers
	what they left open.
]]
function AccessDataService._replicatedContribution(
	serverEntry: { value: boolean?, abstained: boolean?, metadata: any? }?,
	behavior: string?
): { entry: any, aboveLocal: boolean }
	local replicationState = AccessReplicationStateUtils.fromEntry(serverEntry)
	local resolved = behavior or AccessFactServerOverrideBehavior.DEFAULT

	local state = if AccessReplicationStateUtils.hasAnswer(replicationState)
		then AccessFactContributionStateUtils.fromValue(if serverEntry then serverEntry.value else nil)
		else AccessFactContributionState.ABSTAIN

	local aboveLocal = false
	if resolved == AccessFactServerOverrideBehavior.SERVER_OVERRIDE_ALL then
		aboveLocal = true
	elseif resolved == AccessFactServerOverrideBehavior.SERVER_OVERRIDE_ON_ALLOW_ONLY then
		aboveLocal = state == AccessFactContributionState.ALLOW
	elseif resolved == AccessFactServerOverrideBehavior.SERVER_OVERRIDE_ON_DISALLOW_ONLY then
		aboveLocal = state == AccessFactContributionState.DENY
	end

	return {
		aboveLocal = aboveLocal,
		entry = {
			source = REPLICATED_SOURCE,
			priority = if aboveLocal then AccessFactPriority.OVERRIDE - 1 else AccessFactPriority.BUILT_IN - 1,
			-- Attribution rides across replication too. Which friend granted access is resolved on the
			-- server and is precisely what a client UI needs to render, so losing it here would leave the
			-- most useful metadata the package carries stranded on the wrong realm.
			contribution = AccessFact.contributionOfState(state, if serverEntry then serverEntry.metadata else nil),
		},
	}
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
	contributions: {
		{
			source: string,
			priority: number,
			contribution: any,
			terminating: boolean?,
		}
	}
): AccessFactReport
	local report: AccessFactReport = {
		factName = factName,
		state = AccessFactContributionState.UNRESOLVED,
		value = nil,
		metadata = nil,
		decidedBy = nil,
		layers = {},
		-- Filled in by ObserveFactReport; declared here so the shape is complete from the start rather
		-- than growing fields partway through the pipeline.
		localValue = nil,
		serverValue = nil,
		serverState = AccessReplicationState.NOT_YET_ARRIVED,
		serverOverrideBehavior = nil,
		serverOverrode = false,
	}

	local alreadyDecided = false
	local fallback = nil

	for _, entry in contributions do
		local state = entry.contribution.state
		local contributes = AccessFactContributionStateUtils.contributes(state)

		-- A definite yes or no ends the search. UNRESOLVED does not: it is an *observation* that this
		-- layer does not know, and one layer not knowing should not stop a lower one that does -- which is
		-- what lets a fact the client cannot compute be settled by a replicated layer underneath it.
		--
		-- An override is the exception, because it is an *instruction* rather than an observation. Forcing
		-- a fact to unresolved is a thing you ask for on purpose, and a lower layer answering over the top
		-- of it would make the override silently do nothing.
		local terminates = AccessFactContributionStateUtils.isDefinite(state)
			or (entry.terminating == true and contributes)
		local decided = not alreadyDecided and terminates

		if decided then
			alreadyDecided = true
			report.state = state
			report.value = entry.contribution.value
			-- Attribution follows the answer: the report carries the deciding layer's metadata, because
			-- the layers it outranked did not decide anything and their reasons would mislead.
			report.metadata = entry.contribution.metadata
			report.decidedBy = entry.source
		elseif not alreadyDecided and contributes and fallback == nil then
			-- The highest layer that said *something* without saying which way. Used only if nothing
			-- definite turns up, so the readout can still name who left it unresolved.
			fallback = entry
		end

		table.insert(report.layers, {
			source = entry.source,
			priority = entry.priority,
			state = state,
			contributes = contributes,
			value = entry.contribution.value,
			metadata = entry.contribution.metadata,
			decided = decided,
		})
	end

	if not alreadyDecided and fallback then
		report.state = fallback.contribution.state
		report.metadata = fallback.contribution.metadata
		report.decidedBy = fallback.source
	end

	return report
end

--[[
	The facts a feature declared, folded into one table. Facts it did not declare are absent, so a
	mechanism that is broken or slow only stalls the features that asked about it.
]]
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
					return if entry
						then AccessFactContributionStateUtils.fromValue(entry.value)
						else AccessFactContributionState.UNRESOLVED
				end) :: any,
			})
		else
			sources[factName] = self:ObserveFactReport(player, factName):Pipe({
				Rx.map(function(report: AccessFactReport)
					return report.state
				end) :: any,
				Rx.distinct() :: any,
			})
		end
	end

	return Rx.combineLatest(sources) :: any
end

--[[
	Once per name, because a feature re-derives its fact list on every change and would otherwise warn in
	a loop.
]]
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
	abstained: boolean?,
	metadata: any?
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
	next[factName] = { value = value, abstained = abstained, metadata = metadata }
	store.Value = next
end

--[[
	Whether the server has ever said anything about this fact for this player. Distinct from the value
	being nil, which is the server actively saying "unresolved".
]]
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

--[=[
	The overrides in force for this player in *this* realm, live.

	What [AccessPlayer] replicates. A box is present for every overridden fact, and its `value` is absent
	when the override forces unresolved -- which is a thing somebody deliberately does, and so has to
	survive the trip rather than looking like no override at all.

	@param player Player
	@return Observable<{ [string]: { value: boolean? } }>
]=]
function AccessDataService.ObserveFactOverrides(
	self: AccessDataService,
	player: Player
): Observable.Observable<OverrideState>
	assert(player, "Bad player")

	return self:_observeOverrides(player)
end

--[=[
	Applies the overrides the server has in force. The entry point the client's replication arrives
	through, and the seam a test drives directly.

	Overrides are debugging instructions, not entitlements, and an instruction that only took effect in one
	realm would be the worst of both: a console session that opens the server's gate while the client still
	renders it shut, with nothing in either readout saying why.

	An override set locally shadows one that arrives here, so a person investigating in this realm is not
	fighting somebody else's console.

	@param player Player
	@param entries { [string]: { value: boolean? } }
]=]
function AccessDataService.SetReplicatedFactOverrides(
	self: AccessDataService,
	player: Player,
	entries: { [string]: { value: boolean? } }
): ()
	assert(player, "Bad player")
	assert(type(entries) == "table", "Bad entries")

	self:_getReplicatedOverrides(player).Value = entries
end

function AccessDataService._observeReplicatedOverrides(
	self: AccessDataService,
	player: Player
): Observable.Observable<OverrideState>
	return self:_getReplicatedOverrides(player):Observe() :: any
end

-- Same weak-keyed, made-on-first-use shape as the local overrides, and for the same reasons.
function AccessDataService._getReplicatedOverrides(
	self: AccessDataService,
	player: Player
): ValueObject.ValueObject<OverrideState>
	local existing = self._serverOverridesByPlayer[player]
	if existing then
		return existing
	end

	local overrides = ValueObject.new(EMPTY_OVERRIDE_STATE :: any)
	self._serverOverridesByPlayer[player] = overrides

	return overrides
end

--[[
	Created on first use, and deliberately not held by the maid: a strong reference here would defeat the
	weak keys and keep every player who ever joined alive for the session.
]]
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
