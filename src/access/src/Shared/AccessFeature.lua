--!strict
--[=[
	One capability a game gates: entering a chapter, buying an egg, opening a demo area. A feature is
	policy -- it reads facts and **decides**.

	Every judgement lives here: which combination of facts opens a thing, what a release flag means for it,
	inversions, per-thing context. Facts state what is true; features decide what that is worth. That is
	why the same fact can grant one feature and deny another.

	```lua
	-- The common case needs no function.
	local Chapters = AccessFeature.anyOf("chapters", { "ownsGame", "isEarlyAccessTester" })

	-- Anything else declares its non-fact inputs and folds them in.
	local EggPurchase = AccessFeature.new("eggPurchase", {
		facts = { "ownsGame", "isEarlyAccessTester" },
		context = {
			assetId = function(eggName) return observeEggAssetId(eggName) end,
			hasCollected = function(eggName) return observeCollected(eggName) end,
		},
		observeCompute = function(observeFacts, eggName, observeContext)
			return Rx.combineLatest({
				facts = observeFacts,
				context = observeContext,
			}):Pipe({
				Rx.map(EggHuntAccessPolicy.computeEggPurchase),
			})
		end,
	})
	```

	`context` is for inputs that are not facts, because facts are per-*player* and these are per-*thing*:
	an egg's asset, whether it has been collected. Declaring them rather than closing over them inside
	`observeCompute` is what lets a report print them beside the facts -- "why is this egg refused" is
	answered by the context at least as often, and an input nobody can see is an input nobody can debug.

	`observeCompute` is handed the fact observable rather than each fact value, so a feature that needs context of
	its own combines it once instead of rebuilding it every time a fact changes. Keep the verdict itself a
	pure function the pipe maps through -- that is the part worth unit testing, and it stays testable
	without an observable in sight.

	`facts` is declared rather than inferred so an unresolved fact only stalls the features that actually
	read it. One dead mechanism should not leave the whole game unresolved.

	@class AccessFeature
]=]

local require = require(script.Parent.loader).load(script)

local AccessStateUtils = require("AccessStateUtils")
local BaseObject = require("BaseObject")
local Observable = require("Observable")
local Rx = require("Rx")
local RxAccessStateUtils = require("RxAccessStateUtils")
local ValueObject = require("ValueObject")

local AccessFeature = setmetatable({}, BaseObject)
AccessFeature.ClassName = "AccessFeature"
AccessFeature.__index = AccessFeature

--[=[
	@type AccessFeatureCompute (Observable<AccessFactState>, subject: any?) -> Observable<AccessStateUtils>
	@within AccessFeature
]=]
--[=[
	Everything a compute gets beyond its facts and its subject.

	A named bag rather than more positional arguments: facts and subject are what nearly every feature
	uses, and the rest has already grown three times. Adding to this cannot churn a compute that does not
	read it.

	@interface AccessFeatureInput
	.observeContext Observable<{ [string]: any }> -- the declared non-fact inputs, resolved for this subject
	.observeFeatures Observable<{ [string]: AccessState }> -- the declared feature inputs, whole verdicts
	.player Player? -- who this is being decided for
	@within AccessFeature
]=]
export type AccessFeatureInput = {
	observeContext: Observable.Observable<{ [string]: any }>,
	observeFeatures: Observable.Observable<{ [string]: AccessStateUtils.AccessState }>,
	player: Player?,
}

export type AccessFeatureCompute = (
	observeFacts: Observable.Observable<AccessStateUtils.AccessFactState>,
	subject: any?,
	input: AccessFeatureInput
) -> Observable.Observable<AccessStateUtils.AccessState>

--[=[
	Named inputs that are not facts, resolved from the subject.

	@type AccessFeatureContext { [string]: (subject: any?) -> Observable<any> }
	@within AccessFeature
]=]
export type AccessFeatureContext = { [string]: (subject: any?) -> Observable.Observable<any> }

export type AccessFeatureOptions = {
	facts: { string },
	context: AccessFeatureContext?,
	-- Other features whose whole verdict this one reads. Declared, so the service can resolve them and a
	-- report can show them.
	features: { AccessFeature }?,
	requiresSubject: boolean?,
	observeCompute: AccessFeatureCompute,
}

export type AccessFeature =
	typeof(setmetatable(
		{} :: {
			_featureName: string,
			-- Typed loosely on purpose: naming the generic here makes every type that holds an AccessFeature
			-- fail to unify with itself under the old solver, and the cascade reaches half the package.
			_factNames: any,
			_context: AccessFeatureContext,
			-- Loosely typed for the same reason the fact layers are: an array of a BaseObject-derived class
			-- does not unify with itself under the old solver.
			_featureInputs: any,
			_requiresSubject: boolean,
			_pushCounts: { [string]: number? },
			-- The list the feature was written with. A push can never take one of these away.
			_declaredFactNames: { string },
			_compute: AccessFeatureCompute,
		},
		{} :: typeof({ __index = AccessFeature })
	))
	& BaseObject.BaseObject

--[=[
	@param featureName string
	@param options AccessFeatureOptions
	@return AccessFeature
]=]
function AccessFeature.new(featureName: string, options: AccessFeatureOptions): AccessFeature
	assert(type(featureName) == "string" and featureName ~= "", "Bad featureName")
	assert(type(options) == "table", "Bad options")
	assert(type(options.facts) == "table", "Bad options.facts")
	assert(type(options.observeCompute) == "function", "Bad options.observeCompute")
	assert(type(options.context) == "table" or options.context == nil, "Bad options.context")
	assert(type(options.features) == "table" or options.features == nil, "Bad options.features")
	assert(type(options.requiresSubject) == "boolean" or options.requiresSubject == nil, "Bad options.requiresSubject")

	local self: AccessFeature = setmetatable(BaseObject.new() :: any, AccessFeature)

	self._featureName = featureName
	self._factNames = self._maid:Add(ValueObject.new(table.clone(options.facts)))
	self._context = if options.context then table.clone(options.context) else {}
	self._featureInputs = if options.features then table.clone(options.features) else {}
	self._requiresSubject = options.requiresSubject == true
	self._pushCounts = {}
	self._declaredFactNames = table.clone(options.facts)
	self._compute = options.observeCompute

	for _, input in self._featureInputs do
		assert(AccessFeature.isAccessFeature(input), "Bad options.features entry")
	end

	for name, resolve in self._context do
		assert(type(resolve) == "function", `Bad options.context.{name}`)
	end

	return self
end

--[=[
	A feature granted by any one of its facts, unresolved while one is unanswered and nothing else has
	granted, denied only once every answer is in and none of them granted. See [AccessStateUtils.fromFacts].

	@param featureName string
	@param factNames { string }
	@return AccessFeature
]=]
function AccessFeature.anyOf(featureName: string, factNames: { string }): AccessFeature
	assert(type(factNames) == "table", "Bad factNames")

	local feature: AccessFeature

	feature = AccessFeature.new(featureName, {
		facts = table.clone(factNames),
		-- Folds over the feature's own name list, read live so facts pushed on later are included. It has
		-- to be the declared list rather than whatever arrived: only the list knows a fact was *expected*,
		-- and a fact that has not arrived must read as unresolved rather than vanish into a denial.
		observeCompute = function(observeFacts)
			return observeFacts:Pipe({
				Rx.map(function(factState: AccessStateUtils.AccessFactState)
					return AccessStateUtils.fromFacts(factState, feature:GetFactNames())
				end) :: any,
			}) :: any
		end,
	})

	return feature
end

--[=[
	A feature granted only when **every** declared fact allows -- the and-of that a flag-gated grant
	actually is, like `isEarlyAccessTester` *and* `testerEarlyAccessEnabled`.

	Unresolved while any of them is unanswered, refused as soon as one denies. A definite no ends it: no
	later answer can rescue an and-of, so waiting would be a stall with a known answer behind it.

	Facts pushed on later still **widen**, they do not join the and: `allOf(a, b)` granted by a push means
	`(a and b) or pushed`. Anything else would make [AccessFeature.PushFactAllowsFeature] able to take
	access away, which is exactly the surprise it promises not to have.

	@param featureName string
	@param factNames { string }
	@return AccessFeature
]=]
function AccessFeature.allOf(featureName: string, factNames: { string }): AccessFeature
	return AccessFeature._folded(featureName, factNames, AccessStateUtils.fromAllFacts)
end

--[=[
	A feature granted only when **every** declared fact is definitely false -- "does not own the game".

	Unresolved while any of them is unanswered, which is the whole reason this exists rather than a `not`
	in a compute: inverting the value turns unresolved into true, and on a purchase gate that is offering
	to sell somebody something they already have.

	Pushed facts widen, on the same terms as [AccessFeature.allOf].

	@param featureName string
	@param factNames { string }
	@return AccessFeature
]=]
function AccessFeature.noneOf(featureName: string, factNames: { string }): AccessFeature
	return AccessFeature._folded(featureName, factNames, AccessStateUtils.fromNoFacts)
end

-- The declared list is captured, not read live, because for anything but an any-of the two differ: the
-- live list also holds whatever was pushed on, and those are alternative grants rather than more terms.
function AccessFeature._folded(
	featureName: string,
	factNames: { string },
	fold: (AccessStateUtils.AccessFactState, { string }) -> AccessStateUtils.AccessState
): AccessFeature
	assert(type(factNames) == "table", "Bad factNames")

	local declared = table.clone(factNames)
	local feature: AccessFeature

	feature = AccessFeature.new(featureName, {
		facts = table.clone(factNames),
		observeCompute = function(observeFacts)
			return observeFacts:Pipe({
				Rx.map(function(factState: AccessStateUtils.AccessFactState)
					local pushed = {}
					for _, factName in feature:GetFactNames() do
						if not table.find(declared, factName) then
							table.insert(pushed, factName)
						end
					end

					if #pushed == 0 then
						return fold(factState, declared)
					end

					return AccessStateUtils.anyAllowed({
						fold(factState, declared),
						AccessStateUtils.fromFacts(factState, pushed),
					})
				end) :: any,
			}) :: any
		end,
	})

	return feature
end

--[=[
	A feature nothing can gate. Useful as the always-open half of a pair, and as the thing a game registers
	while a real rule is still being written.

	@param featureName string
	@return AccessFeature
]=]
function AccessFeature.alwaysAllowed(featureName: string): AccessFeature
	return AccessFeature.new(featureName, {
		facts = {},
		observeCompute = function()
			return Rx.of(AccessStateUtils.allowed()) :: any
		end,
	})
end

--[=[
	@param value any
	@return boolean
]=]
function AccessFeature.isAccessFeature(value: any): boolean
	return type(value) == "table" and getmetatable(value) == AccessFeature
end

--[=[
	@return string
]=]
function AccessFeature.GetFeatureName(self: AccessFeature): string
	return self._featureName
end

--[=[
	The facts this feature reads. A copy, so a caller cannot quietly widen what the feature depends on.

	@return { string }
]=]
function AccessFeature.GetFactNames(self: AccessFeature): { string }
	return table.clone(self._factNames.Value)
end

--[=[
	The facts this feature reads, live. Changes when something is pushed onto the feature.

	@return Observable<{ string }>
]=]
function AccessFeature.ObserveFactNames(self: AccessFeature): Observable.Observable<{ string }>
	return self._factNames:Observe() :: any
end

--[=[
	Adds a fact that also allows this feature, and hands back a function that removes it again.

	This is how a feature is extended without editing it. A package ships `owns-game` reading a purchase;
	a game pushes a gamepass and a staff allowlist onto the same feature, and everything already gating on
	`owns-game` picks them up.

	```lua
	maid:GiveTask(ownsGame:PushFactAllowsFeature(gamePassFact))
	maid:GiveTask(ownsGame:PushFactAllowsFeature(adminFact))
	```

	The fact must be registered with [AccessDataService] as well -- pushing says *this fact grants this
	feature*, registering says *here is how to answer it*. Pushing an unregistered fact fails loudly when
	the feature is next read, rather than silently never granting.

	Pushing is strictly widening: a pushed fact can grant, never deny. Anything else would make "add a way
	in" able to take one away, which is exactly the sort of surprise this API should not have.

	A push made on the server reaches the client -- [AccessDataService] replicates what each feature reads,
	and the client widens by name. So this is safe to call from server-only code without the two realms
	drifting apart on what the feature means.

	@param fact AccessFact
	@return () -> () -- Removes the fact from this feature
]=]
function AccessFeature.PushFactAllowsFeature(self: AccessFeature, fact: any): () -> ()
	assert(type(fact) == "table" and type(fact.GetFactName) == "function", "Bad fact")

	return self:PushFactNameAllowsFeature(fact:GetFactName())
end

--[=[
	The same widening by name rather than by object, for a realm that has the name but not the fact.

	This is what server-to-client replication of a push arrives through: the client learns that a fact
	grants a feature before -- or without ever -- having a resolver for it, and the value comes over the
	per-player fact replication. Prefer [AccessFeature.PushFactAllowsFeature] anywhere the fact is in hand,
	because passing the object is what makes it obvious the fact has to exist somewhere.

	@param factName string
	@return () -> () -- Removes the fact from this feature
]=]
function AccessFeature.PushFactNameAllowsFeature(self: AccessFeature, factName: string): () -> ()
	assert(type(factName) == "string" and factName ~= "", "Bad factName")

	local current = self._factNames.Value

	-- Counted per name, so a second push of the same fact is a second claim on it rather than a no-op.
	-- A no-op remover looked harmless and was not: whoever pushed first ends up owning the name, and their
	-- remover takes it away from everyone -- which is how replication could revoke a grant that shared
	-- game code had made and expected to keep.
	self._pushCounts[factName] = (self._pushCounts[factName] or 0) + 1

	if not table.find(current, factName) then
		local widened = table.clone(current)
		table.insert(widened, factName)
		self._factNames.Value = widened
	end

	local removed = false

	return function()
		if removed then
			return
		end
		removed = true

		local names = self._factNames.Value
		if not names then
			-- Teardown order is not ours to control: one maid may hold both this remover and the feature,
			-- and taking a fact off a feature that is already gone is a no-op, not an error.
			return
		end

		local remaining = (self._pushCounts[factName] or 1) - 1
		self._pushCounts[factName] = if remaining > 0 then remaining else nil
		if remaining > 0 then
			-- Somebody else still wants it.
			return
		end

		if table.find(self._declaredFactNames, factName) then
			-- The feature reads it in its own right. Pushing a fact it already declares is a claim nobody
			-- needed, and letting that claim expire must not take away what the feature was written with.
			return
		end

		local without = {}
		for _, name in names do
			if name ~= factName then
				table.insert(without, name)
			end
		end
		self._factNames.Value = without
	end
end

--[=[
	Whether asking about this feature without a subject is a meaningless question.

	"Can they enter a world" has no answer; "can they enter world 3" does. Anything that walks the whole
	registry -- the per-player tracker behind [AccessPlayerBase.IsFeatureAllowed], the console dump --
	leaves these alone rather than evaluating them with nothing, which at best reports a verdict nobody
	asked for and at worst runs a compute against a nil it was never written for.

	@return boolean
]=]
function AccessFeature.RequiresSubject(self: AccessFeature): boolean
	return self._requiresSubject
end

--[=[
	The other features this one reads the verdict of.

	Declared rather than reached for inside a compute, because a verdict that came from somewhere the
	report cannot name is a verdict nobody can explain. [FeatureAccessFact] does the other conversion --
	feature to *fact* -- which collapses it to a boolean; this keeps the whole state, so a refusal for
	`boughtAccessDisabled` stays distinguishable from one for `notOwned`.

	Returns loosely typed for the same reason the fact layers are: an array of a BaseObject-derived class
	does not unify with itself under the old solver, and the cascade reaches every caller.

	@return { AccessFeature }
]=]
function AccessFeature.GetFeatureInputs(self: AccessFeature): any
	return table.clone(self._featureInputs)
end

--[=[
	The names of this feature's non-fact inputs.

	@return { string }
]=]
function AccessFeature.GetContextNames(self: AccessFeature): { string }
	local names = {}
	for name in self._context do
		table.insert(names, name)
	end
	table.sort(names)

	return names
end

--[=[
	This feature's non-fact inputs, resolved against a subject, as one table keyed by name.

	Facts are per-player, so anything per-*thing* -- an egg's asset, whether it has been collected -- cannot
	be one. Declaring those here instead of closing over them inside `observeCompute` is what lets a report
	print them beside the facts: an input nobody can see is an input nobody can debug, and "why is this egg
	refused" is answered by the context as often as by the facts.

	Emits an empty table for a feature that declared none, rather than never emitting, so a caller can
	combine it unconditionally.

	@param subject any?
	@return Observable<{ [string]: any }>
]=]
function AccessFeature.ObserveContext(self: AccessFeature, subject: any?): Observable.Observable<{ [string]: any }>
	local sources: { [string]: any } = {}
	for name, resolve in self._context do
		sources[name] = resolve(subject)
	end

	if next(sources) == nil then
		return RxAccessStateUtils.ofStatic({}) :: any
	end

	return Rx.combineLatest(sources) :: any
end

--[=[
	A plain snapshot of this feature, including anything pushed onto it since it was written.

	@return { featureName: string, facts: { string }, context: { string } }
]=]
function AccessFeature.GetDebugState(self: AccessFeature): {
	featureName: string,
	facts: { string },
	context: { string },
	requiresSubject: boolean,
}
	return {
		featureName = self._featureName,
		facts = self:GetFactNames(),
		context = self:GetContextNames(),
		requiresSubject = self._requiresSubject,
	}
end

--[=[
	Runs the feature's policy. Called by [AccessDataService], which supplies the fact observable.

	`observeFeatures` and `player` can only come from [AccessDataService], which has the registry and knows
	who is being asked about. A feature declaring no feature inputs gets an empty map rather than nothing,
	so a compute can combine it unconditionally.

	@param observeFacts Observable<AccessFactState>
	@param subject any?
	@param extras { observeFeatures: Observable<{ [string]: AccessState }>?, player: Player? }?
	@return Observable<AccessStateUtils>
]=]
function AccessFeature.ObserveCompute(
	self: AccessFeature,
	observeFacts: Observable.Observable<AccessStateUtils.AccessFactState>,
	subject: any?,
	extras: { observeFeatures: any?, player: Player? }?
): Observable.Observable<AccessStateUtils.AccessState>
	local input: AccessFeatureInput = {
		observeContext = self:ObserveContext(subject),
		observeFeatures = (extras and extras.observeFeatures) or RxAccessStateUtils.ofStatic({}) :: any,
		player = extras and extras.player,
	}

	local result = self._compute(observeFacts, subject, input)

	assert(
		Observable.isObservable(result),
		`[AccessFeature] - observeCompute for {self._featureName} must return an Observable<AccessStateUtils>`
	)

	return result
end

return AccessFeature
