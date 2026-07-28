--!strict
--[=[
	The scripter-facing view of one player's access. Bound to every player in both realms, so anything
	holding a `Player` can ask about them without reaching for a service or knowing a registry exists.

	```lua
	local accessPlayer = AccessPlayerInterface:Find(player)

	if accessPlayer:IsFeatureAllowed(MyFeatures.Chapters) then ... end

	accessPlayer:ObserveIsFeatureAllowed(MyFeatures.Chapters):Subscribe(function(isAllowed) ... end)
	accessPlayer:PromiseIsFeatureAllowed(MyFeatures.Chapters):Then(function(isAllowed) ... end)
	```

	Three shapes of the same question because callers genuinely differ: a guard wants a boolean now, a UI
	wants a stream, and a gate wants to wait for a real answer. They agree by construction -- all three
	read [AccessDataService], which is still the only thing that decides anything. This class holds no
	rules of its own.

	## Boolean versus the full verdict

	`IsFeatureAllowed` collapses unresolved to **false**, because a boolean has nowhere to put a third
	answer and failing closed is the safe half. When the difference matters -- offering a purchase, saying
	*why* somebody is refused -- use `GetFeatureAllowedState` and friends, which hand back the whole
	[AccessStateUtils.AccessState].

	## Where replicated facts live

	The server half writes what it resolved onto a JSON attribute of the player instance, and the client
	half reads it. Player instances replicate to *every* client, so one player's access state is legible
	to all of them -- a party UI can say who is missing a chapter without asking anyone.

	That also means facts are **public**. Anything that must not be visible to other players does not
	belong in one.

	@class AccessPlayerBase
]=]

local require = require(script.Parent.loader).load(script)

local AccessDataService = require("AccessDataService")
local AccessFeature = require("AccessFeature")
local AccessReplicationStateUtils = require("AccessReplicationStateUtils")
local AccessStateUtils = require("AccessStateUtils")
local BaseObject = require("BaseObject")
local JSONAttributeValue = require("JSONAttributeValue")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local Rx = require("Rx")
local ServiceBag = require("ServiceBag")
local Signal = require("Signal")

--[=[
	The attribute carrying this player's server-resolved facts, as
	`{ [factName]: { value: boolean?, abstained: boolean? } }`. One attribute rather than one per fact so
	a whole snapshot lands atomically instead of a UI seeing a half-updated set.

	@prop REPLICATED_FACTS_ATTRIBUTE string
	@within AccessPlayerBase
]=]
local REPLICATED_FACTS_ATTRIBUTE = "AccessFacts"
local REPLICATED_OVERRIDES_ATTRIBUTE = "AccessFactOverrides"

local AccessPlayerBase = setmetatable({}, BaseObject)
AccessPlayerBase.ClassName = "AccessPlayerBase"
AccessPlayerBase.__index = AccessPlayerBase

export type AccessPlayerBase =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_accessDataService: any,
			_stateByFeatureName: { [string]: any },
			_replicatedFacts: any,
			_replicatedOverrides: any,
			FeatureAllowedChanged: any,
		},
		{} :: typeof({ __index = AccessPlayerBase })
	))
	& BaseObject.BaseObject

--[=[
	@param player Player
	@param serviceBag ServiceBag
	@return AccessPlayerBase
]=]
function AccessPlayerBase.new(player: Player, serviceBag: ServiceBag.ServiceBag): AccessPlayerBase
	local self: AccessPlayerBase = setmetatable(BaseObject.new(player) :: any, AccessPlayerBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._accessDataService = self._serviceBag:GetService(AccessDataService)
	self._stateByFeatureName = {}
	self._replicatedFacts = JSONAttributeValue.new(player, REPLICATED_FACTS_ATTRIBUTE, {})
	self._replicatedOverrides = JSONAttributeValue.new(player, REPLICATED_OVERRIDES_ATTRIBUTE, {})

	--[=[
		Fires when a feature's verdict changes for this player, with the feature name, whether it is now
		allowed, and the whole state.

		Covers features that take no subject -- a per-thing feature has nothing to evaluate without one, so
		reach those through [AccessPlayerBase.ObserveIsFeatureAllowed] with the subject.

		@prop FeatureAllowedChanged Signal<(string, boolean, AccessState)>
		@within AccessPlayerBase
	]=]
	self.FeatureAllowedChanged = self._maid:Add(Signal.new())

	self:_trackRegisteredFeatures()

	return self
end

--[=[
	@param value any
	@return boolean
]=]
function AccessPlayerBase.isAccessPlayer(value: any): boolean
	return type(value) == "table" and getmetatable(value) == AccessPlayerBase
end

--[=[
	Whether this player may use the feature, right now. Unresolved reads as false.

	@param feature AccessFeature
	@param subject any?
	@return boolean
]=]
function AccessPlayerBase.IsFeatureAllowed(
	self: AccessPlayerBase,
	feature: AccessFeature.AccessFeature,
	subject: any?
): boolean
	return AccessStateUtils.isAllowed(self:GetFeatureAllowedState(feature, subject))
end

--[=[
	@param featureName string
	@param subject any?
	@return boolean
]=]
function AccessPlayerBase.IsFeatureAllowedByName(self: AccessPlayerBase, featureName: string, subject: any?): boolean
	return self._accessDataService:IsFeatureAllowedByName(self._obj, featureName, subject)
end

--[=[
	The whole verdict, right now, for callers that must tell a refusal from a non-answer.

	@param feature AccessFeature
	@param subject any?
	@return AccessState
]=]
function AccessPlayerBase.GetFeatureAllowedState(
	self: AccessPlayerBase,
	feature: AccessFeature.AccessFeature,
	subject: any?
): AccessStateUtils.AccessState
	assert(AccessFeature.isAccessFeature(feature), "Bad feature")

	-- Cached for subject-less features, which is the common case and the one a guard hits in a loop.
	local cached = self._stateByFeatureName[feature:GetFeatureName()]
	if cached ~= nil and subject == nil then
		return cached
	end

	return AccessPlayerBase._readOnce(self:ObserveFeatureAllowedState(feature, subject))
		or AccessStateUtils.unresolved()
end

--[=[
	@param featureName string
	@param subject any?
	@return AccessState
]=]
function AccessPlayerBase.GetFeatureAllowedStateByName(
	self: AccessPlayerBase,
	featureName: string,
	subject: any?
): AccessStateUtils.AccessState
	return AccessPlayerBase._readOnce(self:ObserveFeatureAllowedStateByName(featureName, subject))
		or AccessStateUtils.unresolved()
end

--[=[
	@param feature AccessFeature
	@param subject any?
	@return Observable<boolean>
]=]
function AccessPlayerBase.ObserveIsFeatureAllowed(
	self: AccessPlayerBase,
	feature: AccessFeature.AccessFeature,
	subject: any?
): Observable.Observable<boolean>
	return self._accessDataService:ObserveIsAllowed(self._obj, feature, subject)
end

--[=[
	@param featureName string
	@param subject any?
	@return Observable<boolean>
]=]
function AccessPlayerBase.ObserveIsFeatureAllowedByName(
	self: AccessPlayerBase,
	featureName: string,
	subject: any?
): Observable.Observable<boolean>
	return self._accessDataService:ObserveIsFeatureAllowedByName(self._obj, featureName, subject)
end

--[=[
	@param feature AccessFeature
	@param subject any?
	@return Observable<AccessState>
]=]
function AccessPlayerBase.ObserveFeatureAllowedState(
	self: AccessPlayerBase,
	feature: AccessFeature.AccessFeature,
	subject: any?
): Observable.Observable<AccessStateUtils.AccessState>
	return self._accessDataService:ObserveFeature(self._obj, feature, subject)
end

--[=[
	@param featureName string
	@param subject any?
	@return Observable<AccessState>
]=]
function AccessPlayerBase.ObserveFeatureAllowedStateByName(
	self: AccessPlayerBase,
	featureName: string,
	subject: any?
): Observable.Observable<AccessStateUtils.AccessState>
	return self._accessDataService:ObserveFeatureAllowedStateByName(self._obj, featureName, subject)
end

--[=[
	Settles once there is a real verdict, skipping unresolved. Rejects if the player leaves first.

	@param feature AccessFeature
	@param subject any?
	@return Promise<boolean>
]=]
function AccessPlayerBase.PromiseIsFeatureAllowed(
	self: AccessPlayerBase,
	feature: AccessFeature.AccessFeature,
	subject: any?
): Promise.Promise<boolean>
	return self:PromiseFeatureAllowedState(feature, subject):Then(function(state)
		return AccessStateUtils.isAllowed(state)
	end) :: any
end

--[=[
	@param featureName string
	@param subject any?
	@return Promise<boolean>
]=]
function AccessPlayerBase.PromiseIsFeatureAllowedByName(
	self: AccessPlayerBase,
	featureName: string,
	subject: any?
): Promise.Promise<boolean>
	return self._accessDataService:PromiseIsFeatureAllowedByName(self._obj, featureName, subject)
end

--[=[
	@param feature AccessFeature
	@param subject any?
	@return Promise<AccessState>
]=]
function AccessPlayerBase.PromiseFeatureAllowedState(
	self: AccessPlayerBase,
	feature: AccessFeature.AccessFeature,
	subject: any?
): Promise.Promise<AccessStateUtils.AccessState>
	return self._accessDataService:PromiseFeature(self._obj, feature, subject)
end

--[=[
	Why a fact reads the way it does -- the deciding layer's attribution, in whatever shape that mechanism
	attached. This is what a UI renders: which friends granted you access, which gamepass covered you.

	Nil when the fact attached none, or when nothing decided it.

	@param factName string
	@return any?
]=]
function AccessPlayerBase.GetFactMetadata(self: AccessPlayerBase, factName: string): any?
	local report = AccessPlayerBase._readOnce(self._accessDataService:ObserveFactReport(self._obj, factName))

	return if report then report.metadata else nil
end

--[=[
	The same attribution, live, for a UI that has to follow it.

	@param factName string
	@return Observable<any?>
]=]
function AccessPlayerBase.ObserveFactMetadata(self: AccessPlayerBase, factName: string): Observable.Observable<any?>
	return self._accessDataService:ObserveFactReport(self._obj, factName):Pipe({
		Rx.map(function(report: any)
			return report.metadata
		end) :: any,
	}) :: any
end

--[=[
	What the server resolved for this player, keyed by fact name, each with its
	[AccessReplicationState]. Readable for **any** player, not just the local one.

	@return { [string]: { value: boolean?, state: string } }
]=]
function AccessPlayerBase.GetReplicatedFacts(self: AccessPlayerBase): { [string]: any }
	local described = {}

	for factName, entry in self._replicatedFacts.Value or {} do
		described[factName] = {
			value = entry.value,
			state = AccessReplicationStateUtils.fromEntry(entry),
		}
	end

	return described
end

--[=[
	The same, live.

	@return Observable<{ [string]: { value: boolean?, state: string } }>
]=]
function AccessPlayerBase.ObserveReplicatedFacts(self: AccessPlayerBase): Observable.Observable<{ [string]: any }>
	return self._replicatedFacts:Observe():Pipe({
		Rx.map(function()
			return self:GetReplicatedFacts()
		end) :: any,
	}) :: any
end

--[=[
	Every feature's current verdict for this player, plus every fact underneath. What to print when
	somebody says they cannot get in.

	@return { featureStates: { [string]: any }, facts: { [string]: any } }
]=]
function AccessPlayerBase.GetDebugState(self: AccessPlayerBase): { featureStates: { [string]: any }, facts: any }
	local featureStates = {}
	for featureName, state in self._stateByFeatureName do
		featureStates[featureName] = {
			allowed = AccessStateUtils.isAllowed(state),
			state = state,
		}
	end

	return {
		featureStates = featureStates,
		facts = AccessPlayerBase._readOnce(self._accessDataService:ObserveFactReports(self._obj)) or {},
	}
end

--[[
	Subscribes to every registered subject-less feature, so IsFeatureAllowed is a real synchronous read
	and FeatureAllowedChanged fires for all of them rather than only for whatever was asked about first.
	Rebuilt wholesale on registry changes -- the fan-in behind them is already shared, so it is cheap.
]]
function AccessPlayerBase._trackRegisteredFeatures(self: AccessPlayerBase): ()
	self._maid:GiveTask(self._accessDataService:ObserveFeatureNames():Subscribe(function(featureNames: { string })
		local featureMaid = Maid.new()

		for _, featureName in featureNames do
			local feature = self._accessDataService:GetFeature(featureName)
			-- A per-thing feature has no answer without the thing. Evaluating it with nil here is what
			-- crashed a purchase gate that had every right to assume it had a subject.
			if feature and not feature:RequiresSubject() then
				featureMaid:GiveTask(self:ObserveFeatureAllowedState(feature):Subscribe(function(state)
					self._stateByFeatureName[featureName] = state
					self.FeatureAllowedChanged:Fire(featureName, AccessStateUtils.isAllowed(state), state)
				end))
			end
		end

		self._maid._featureMaid = featureMaid
	end))
end

--[[
	GOTCHA: keeps the LAST emission. Access observables open on unresolved before anything is looked up,
	so the first would read unresolved however well resolved the fact is.
]]
function AccessPlayerBase._readOnce(observable: any): any
	local captured = nil
	local subscription = observable:Subscribe(function(value)
		captured = value
	end)
	subscription:Destroy()

	return captured
end

AccessPlayerBase.REPLICATED_FACTS_ATTRIBUTE = REPLICATED_FACTS_ATTRIBUTE

--[=[
	The attribute the server's fact overrides arrive on.

	@prop REPLICATED_OVERRIDES_ATTRIBUTE string
	@within AccessPlayerBase
]=]
AccessPlayerBase.REPLICATED_OVERRIDES_ATTRIBUTE = REPLICATED_OVERRIDES_ATTRIBUTE

return AccessPlayerBase
