--!strict
--[=[
	Something that *happens* because of a verdict. Facts say what is true, features say what that means,
	and a policy is the consequence -- kicking, teleporting, closing a door.

	```lua
	AccessPolicy.new("kickOnNonAdmin", {
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

local AccessFeature = require("AccessFeature")
local AccessPolicyRealm = require("AccessPolicyRealm")
local AccessStateUtils = require("AccessStateUtils")
local Observable = require("Observable")

local AccessPolicy = {}
AccessPolicy.ClassName = "AccessPolicy"
AccessPolicy.__index = AccessPolicy

--[=[
	What a policy is handed when it is applied to a player. `observeFact` and `observeFeature` refuse
	anything the policy did not declare, so the declaration cannot drift from what it actually reads.

	@interface AccessPolicyContext
	.player Player
	.observeFact (factName: string) -> Observable<boolean?>
	.observeFeature (feature: AccessFeature, subject: any?) -> Observable<AccessState>
	@within AccessPolicy
]=]
export type AccessPolicyContext = {
	player: Player,
	observeFact: (factName: string) -> Observable.Observable<boolean?>,
	observeFeature: (
		feature: AccessFeature.AccessFeature,
		subject: any?
	) -> Observable.Observable<AccessStateUtils.AccessState>,
}

--[=[
	Runs the policy for one player. Return anything a [Maid] can clean up; it is torn down when the policy
	is disabled or the player leaves.

	@type AccessPolicyApply (AccessPolicyContext) -> any
	@within AccessPolicy
]=]
export type AccessPolicyApply = (context: AccessPolicyContext) -> any

export type AccessPolicyOptions = {
	facts: { string }?,
	features: { AccessFeature.AccessFeature }?,
	realm: string?,
	apply: AccessPolicyApply,
}

export type AccessPolicy = typeof(setmetatable(
	{} :: {
		_policyName: string,
		_factNames: { string },
		_features: { AccessFeature.AccessFeature },
		_apply: AccessPolicyApply,
		_realm: string,
	},
	{} :: typeof({ __index = AccessPolicy })
))

--[=[
	@param policyName string
	@param options AccessPolicyOptions
	@return AccessPolicy
]=]
function AccessPolicy.new(policyName: string, options: AccessPolicyOptions): AccessPolicy
	assert(type(policyName) == "string" and policyName ~= "", "Bad policyName")
	assert(type(options) == "table", "Bad options")
	assert(type(options.apply) == "function", "Bad options.apply")
	assert(type(options.facts) == "table" or options.facts == nil, "Bad options.facts")
	assert(type(options.features) == "table" or options.features == nil, "Bad options.features")
	assert(type(options.realm) == "string" or options.realm == nil, "Bad options.realm")

	local self: AccessPolicy = setmetatable({} :: any, AccessPolicy)

	self._policyName = policyName
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

--[=[
	Runs the policy. Called by [AccessPolicyService] when the policy is enabled for a player.

	@param context AccessPolicyContext
	@return any -- A maid task
]=]
function AccessPolicy.Apply(self: AccessPolicy, context: AccessPolicyContext): any
	return self._apply(context)
end

return AccessPolicy
