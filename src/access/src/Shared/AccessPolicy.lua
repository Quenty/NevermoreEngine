--!strict
--[=[
	Something that *happens* because of a verdict. Facts say what is true, features say what that means,
	and a policy is the consequence -- kicking, teleporting, closing a door.

	```lua
	AccessPolicy.new(serviceBag, {
		policyName = "kickOnNonAdmin",
		facts = { AccessFactNames.PLAYER_IS_ADMIN },
		apply = function(context)
			return context.observeFact(AccessFactNames.PLAYER_IS_ADMIN):Subscribe(function(isAdmin)
				if isAdmin == false then
					kick(context.player)
				end
			end)
		end,
	})
	```

	A policy declares what it reads, the same way a feature does, and its context only hands back what it
	declared. That is why policies may read facts directly when ordinary call sites may not: a policy is a
	registered, named, declaring consumer whose inputs show up in a readout, not an anonymous `if`
	somewhere in a UI file.

	Policies are registered disabled. Turning one on is a deliberate act -- from a console command or a
	test -- which is what makes a consequence as blunt as kicking safe to ship in the box.

	Registration happens in **both realms**, so a console on either side knows every policy name. An
	[AccessPolicyRealm] decides where `apply` actually runs: kicking is server-side, showing a locked
	banner is client-side.

	@class AccessPolicy
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessFeature = require("AccessFeature")
local AccessPolicyContextUtils = require("AccessPolicyContextUtils")
local AccessPolicyRealm = require("AccessPolicyRealm")
local AccessPolicyServiceInterface = require("AccessPolicyServiceInterface")
local BaseObject = require("BaseObject")
local Maid = require("Maid")
local MaidTaskUtils = require("MaidTaskUtils")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")

local AccessPolicy = setmetatable({}, BaseObject)
AccessPolicy.ClassName = "AccessPolicy"
AccessPolicy.__index = AccessPolicy

--[=[
	@type AccessPolicyContext AccessPolicyContextUtils.AccessPolicyContext
	@within AccessPolicy
]=]
export type AccessPolicyContext = AccessPolicyContextUtils.AccessPolicyContext

--[=[
	Runs the policy for one player. Return a [MaidTaskUtils.MaidTask] -- a subscription, a connection, a
	function -- and it is cleaned up when the policy is disabled, the player leaves, or the policy itself
	is destroyed.

	@type AccessPolicyApply (AccessPolicyContext) -> MaidTask?
	@within AccessPolicy
]=]
export type AccessPolicyApply = (context: AccessPolicyContext) -> MaidTaskUtils.MaidTask?

export type AccessPolicyOptions = {
	policyName: string,
	facts: { string }?,
	features: { AccessFeature.AccessFeature }?,
	realm: string?,
	apply: AccessPolicyApply,
}

export type AccessPolicy =
	typeof(setmetatable(
		{} :: {
			_policyName: string,
			_factNames: { string },
			_features: { AccessFeature.AccessFeature },
			_apply: AccessPolicyApply,
			_realm: string,
			_serviceBag: ServiceBag.ServiceBag,
			_tieRealmService: any,
		},
		{} :: typeof({ __index = AccessPolicy })
	))
	& BaseObject.BaseObject

--[=[
	A [ServiceBag] rather than none, because a policy has to look itself up through
	[AccessPolicyServiceInterface] and that lookup needs a tie realm. Taking the bag means the realm comes
	from [TieRealmService] -- the same source production uses -- rather than being guessed from
	`RunService`, which is what a test running both realms in one DataModel would get wrong.

	Policies are built by application code, which already has a bag, so this costs the caller nothing.

	@param serviceBag ServiceBag
	@param options AccessPolicyOptions
	@return AccessPolicy
]=]
function AccessPolicy.new(serviceBag: ServiceBag.ServiceBag, options: AccessPolicyOptions): AccessPolicy
	assert(serviceBag, "No serviceBag")
	assert(type(options) == "table", "Bad options")
	assert(type(options.policyName) == "string" and options.policyName ~= "", "Bad options.policyName")
	assert(type(options.apply) == "function", "Bad options.apply")
	assert(type(options.facts) == "table" or options.facts == nil, "Bad options.facts")
	assert(type(options.features) == "table" or options.features == nil, "Bad options.features")
	assert(type(options.realm) == "string" or options.realm == nil, "Bad options.realm")

	local self: AccessPolicy = setmetatable(BaseObject.new() :: any, AccessPolicy)

	self._serviceBag = serviceBag
	self._tieRealmService = self._serviceBag:GetService(TieRealmService)
	self._policyName = options.policyName
	self._factNames = if options.facts then table.clone(options.facts) else {}
	self._features = if options.features then table.clone(options.features) else {}
	self._apply = options.apply
	self._realm = options.realm or AccessPolicyRealm.BOTH

	return self
end

--[=[
	@param value any
	@return boolean
]=]
function AccessPolicy.isAccessPolicy(value: any): boolean
	return type(value) == "table" and getmetatable(value) == AccessPolicy
end

--[=[
	@return string
]=]
function AccessPolicy.GetPolicyName(self: AccessPolicy): string
	return self._policyName
end

--[=[
	@return { string }
]=]
function AccessPolicy.GetFactNames(self: AccessPolicy): { string }
	return table.clone(self._factNames)
end

--[=[
	@return { AccessFeature }
]=]
function AccessPolicy.GetFeatures(self: AccessPolicy): { AccessFeature.AccessFeature }
	return table.clone(self._features)
end

--[=[
	Where this policy's consequence runs. It is registered in both realms either way, so a console on
	either side can name it.

	@return string
]=]
function AccessPolicy.GetRealm(self: AccessPolicy): string
	return self._realm
end

--[=[
	@param isServer boolean
	@return boolean
]=]
function AccessPolicy.RunsInRealm(self: AccessPolicy, isServer: boolean): boolean
	return AccessPolicyRealm.runsHere(self._realm, isServer)
end

--[=[
	@param factName string
	@return boolean
]=]
function AccessPolicy.DeclaresFact(self: AccessPolicy, factName: string): boolean
	return table.find(self._factNames, factName) ~= nil
end

--[=[
	@param feature AccessFeature
	@return boolean
]=]
function AccessPolicy.DeclaresFeature(self: AccessPolicy, feature: AccessFeature.AccessFeature): boolean
	return table.find(self._features, feature) ~= nil
end

--[=[
	A plain snapshot of this policy: what it is, where it runs, and what it reads.

	@return { policyName: string, realm: string, facts: { string }, features: { string } }
]=]
function AccessPolicy.GetDebugState(self: AccessPolicy): {
	policyName: string,
	realm: string,
	facts: { string },
	features: { string },
}
	local featureNames = {}
	for _, feature in self._features do
		table.insert(featureNames, feature:GetFeatureName())
	end

	return {
		policyName = self._policyName,
		realm = self._realm,
		facts = self:GetFactNames(),
		features = featureNames,
	}
end

function AccessPolicy._findService(self: AccessPolicy): any
	return AccessPolicyServiceInterface:Find(ReplicatedStorage, self._tieRealmService:GetTieRealm())
end

--[=[
	Whether this policy is *active* for the player right now: enabled, in this realm, and this player
	being tracked. See [AccessPolicyService] for the enabled-versus-active distinction.

	Shallow: it asks the service through [AccessPolicyServiceInterface] rather than holding one, so a
	policy stays a description that happens to be able to look itself up, and answers false in a game
	with no access service rather than erroring.

	@param player Player
	@return boolean
]=]
function AccessPolicy.IsPolicyActiveForPlayer(self: AccessPolicy, player: Player): boolean
	local service = self:_findService()
	if not service then
		return false
	end

	return (service :: any):IsPolicyActiveForPlayer(player, self._policyName)
end

--[=[
	The same question, live.

	@param player Player
	@return Observable<boolean>
]=]
function AccessPolicy.ObserveIsPolicyActiveForPlayer(self: AccessPolicy, player: Player): any
	local service = assert(self:_findService(), "[AccessPolicy] - No AccessPolicyService is running")

	return (service :: any):ObserveIsPolicyActiveForPlayer(player, self._policyName)
end

--[=[
	Settles once this policy is running for the player.

	@param player Player
	@return Promise<boolean>
]=]
function AccessPolicy.PromiseIsPolicyActiveForPlayer(self: AccessPolicy, player: Player): any
	local service = assert(self:_findService(), "[AccessPolicy] - No AccessPolicyService is running")

	return (service :: any):PromiseIsPolicyActiveForPlayer(player, self._policyName)
end

--[=[
	Runs the policy. Called by [AccessPolicyService] when the policy is enabled for a player.

	The returned task is owned twice over: by the caller, which drops it when the policy is disabled or
	the player leaves, and by this policy, which drops it when the policy itself is destroyed. Unlike
	[AccessFact] and [AccessFeature] -- which are inert descriptions -- a policy is *running*, so it needs
	a lifetime of its own and everything it started has to end with it.

	@param context AccessPolicyContext
	@return MaidTask?
]=]
function AccessPolicy.Apply(self: AccessPolicy, context: AccessPolicyContext): MaidTaskUtils.MaidTask?
	local task = self._apply(context)
	if task == nil then
		return nil
	end

	assert(MaidTaskUtils.isValidTask(task), "Bad task returned from an AccessPolicy apply")

	-- Held by the policy as well as the caller, so destroying a policy stops everything it started even
	-- if whoever applied it forgets.
	local applicationMaid = self._maid:Add(Maid.new())
	applicationMaid:GiveTask(task)

	return function()
		applicationMaid:DoCleaning()
		self._maid[applicationMaid] = nil
	end
end

return AccessPolicy
