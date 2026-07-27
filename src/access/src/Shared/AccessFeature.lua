--!strict
--[=[
	One capability a game gates: entering a chapter, buying an egg, opening a demo area. A feature is
	policy -- it reads facts and decides. Flags, inversions, and anything else game-shaped live here rather
	than in [AccessFact], so the same fact can grant one feature and deny another.

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
local Observable = require("Observable")
local Rx = require("Rx")
local ValueObject = require("ValueObject")

local AccessFeature = {}
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

export type AccessFeature = typeof(setmetatable(
	{} :: {
		_featureName: string,
		-- Typed loosely on purpose: naming the generic here makes every type that holds an AccessFeature
		-- fail to unify with itself under the old solver, and the cascade reaches half the package.
		_factNames: any,
		_compute: AccessFeatureCompute,
	},
	{} :: typeof({ __index = AccessFeature })
))

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

	local self: AccessFeature = setmetatable({} :: any, AccessFeature)

	self._featureName = featureName
	self._factNames = ValueObject.new(table.clone(options.facts))
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
		-- Reads the feature's names at fold time rather than the list captured here, so a fact pushed on
		-- later grants it too.
		--
		-- GOTCHA: it has to be the name list, not the keys of `factState`. Rx.combineLatest drops keys
		-- whose value is nil, and nil is precisely how a fact says "unresolved" -- so folding over what
		-- arrived would make every unanswered fact disappear and report a confident denial.
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

	@param fact AccessFact
	@return () -> () -- Removes the fact from this feature
]=]
function AccessFeature.PushFactAllowsFeature(self: AccessFeature, fact: any): () -> ()
	assert(type(fact) == "table" and type(fact.GetFactName) == "function", "Bad fact")

	local factName = fact:GetFactName()
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

		local without = {}
		for _, name in self._factNames.Value do
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
