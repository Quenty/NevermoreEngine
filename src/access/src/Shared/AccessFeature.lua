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

	-- Anything else composes its own context in.
	local EggPurchase = AccessFeature.new("eggPurchase", {
		facts = { "ownsGame", "isEarlyAccessTester" },
		observeCompute = function(observeFacts, eggName)
			return Rx.combineLatest({
				facts = observeFacts,
				context = observeEggContext(eggName),
			}):Pipe({
				Rx.map(EggHuntAccessPolicy.computeEggPurchase),
			})
		end,
	})
	```

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
local ValueObject = require("ValueObject")

local AccessFeature = setmetatable({}, BaseObject)
AccessFeature.ClassName = "AccessFeature"
AccessFeature.__index = AccessFeature

--[=[
	@type AccessFeatureCompute (Observable<AccessFactState>, subject: any?) -> Observable<AccessStateUtils>
	@within AccessFeature
]=]
export type AccessFeatureCompute = (
	observeFacts: Observable.Observable<AccessStateUtils.AccessFactState>,
	subject: any?
) -> Observable.Observable<AccessStateUtils.AccessState>

export type AccessFeatureOptions = {
	facts: { string },
	observeCompute: AccessFeatureCompute,
}

export type AccessFeature =
	typeof(setmetatable(
		{} :: {
			_featureName: string,
			-- Typed loosely on purpose: naming the generic here makes every type that holds an AccessFeature
			-- fail to unify with itself under the old solver, and the cascade reaches half the package.
			_factNames: any,
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

	local self: AccessFeature = setmetatable(BaseObject.new() :: any, AccessFeature)

	self._featureName = featureName
	self._factNames = self._maid:Add(ValueObject.new(table.clone(options.facts)))
	self._compute = options.observeCompute

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

	if table.find(current, factName) then
		-- Already read by this feature. Handing back a remover that took it away would let one caller
		-- revoke another's grant, so this one does nothing.
		return function() end
	end

	local widened = table.clone(current)
	table.insert(widened, factName)
	self._factNames.Value = widened

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
	A plain snapshot of this feature, including anything pushed onto it since it was written.

	@return { featureName: string, facts: { string } }
]=]
function AccessFeature.GetDebugState(self: AccessFeature): { featureName: string, facts: { string } }
	return {
		featureName = self._featureName,
		facts = self:GetFactNames(),
	}
end

--[=[
	Runs the feature's policy. Called by [AccessDataService], which supplies the fact observable.

	@param observeFacts Observable<AccessFactState>
	@param subject any?
	@return Observable<AccessStateUtils>
]=]
function AccessFeature.ObserveCompute(
	self: AccessFeature,
	observeFacts: Observable.Observable<AccessStateUtils.AccessFactState>,
	subject: any?
): Observable.Observable<AccessStateUtils.AccessState>
	local result = self._compute(observeFacts, subject)

	assert(
		Observable.isObservable(result),
		`[AccessFeature] - observeCompute for {self._featureName} must return an Observable<AccessStateUtils>`
	)

	return result
end

return AccessFeature
