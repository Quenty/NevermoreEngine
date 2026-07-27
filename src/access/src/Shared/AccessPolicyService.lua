--!strict
--[=[
	Registers [AccessPolicy] objects and runs the enabled ones against each player.

	Policies register **disabled**. A policy that is off is still listed, still autocompletes, and still
	names what it reads -- it simply is not running. That is what makes a consequence as blunt as kicking
	safe to ship in the box: turning it on is a deliberate act you can see in a readout, and turning it
	off again is one command rather than a deploy.

	Shared, and registration happens in both realms, so a console on either side can name and autocomplete
	every policy. Where a policy's consequence actually runs is its [AccessPolicyRealm] -- kicking on the
	server, presentation on the client -- and this service simply skips the ones that are not for here.

	@class AccessPolicyService
]=]

local require = require(script.Parent.loader).load(script)

local AccessDataService = require("AccessDataService")
local AccessFactNames = require("AccessFactNames")
local AccessFeature = require("AccessFeature")
local AccessKickPolicy = require("AccessKickPolicy")
local AccessPolicy = require("AccessPolicy")
local AccessPolicyNames = require("AccessPolicyNames")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableMap = require("ObservableMap")
local Rx = require("Rx")
local RunService = game:GetService("RunService")
local ServiceBag = require("ServiceBag")

local AccessPolicyService = {}
AccessPolicyService.ServiceName = "AccessPolicyService"

export type AccessPolicyService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_accessDataService: AccessDataService.AccessDataService,
		_policies: ObservableMap.ObservableMap<string, AccessPolicy.AccessPolicy>,
		_enabled: { [string]: boolean },
		-- One maid per player, holding one task per enabled policy, keyed by policy name so a policy can be
		-- switched off for everyone without disturbing the others.
		_playerMaids: { [any]: Maid.Maid },
		_alive: boolean,
	},
	{} :: typeof({ __index = AccessPolicyService })
))

function AccessPolicyService.Init(self: AccessPolicyService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._accessDataService = self._serviceBag:GetService(AccessDataService) :: any
	local policies = ObservableMap.new()
	self._policies = policies :: any
	self._maid:GiveTask(policies)
	self._enabled = {}
	self._playerMaids = {}
	self._alive = true

	self:_registerBuiltInPolicies()
end

-- Registered in both realms so the name exists everywhere, and disabled so shipping one does not switch
-- it on. A game that wants different wording registers its own and leaves this one off.
function AccessPolicyService._registerBuiltInPolicies(self: AccessPolicyService): ()
	self._maid:GiveTask(
		self:RegisterPolicy(
			AccessKickPolicy.whenFactIs(
				AccessPolicyNames.KICK_ON_NON_ADMIN,
				AccessFactNames.PLAYER_IS_ADMIN,
				false,
				{ message = "This place is currently limited to the development team." }
			)
		)
	)
end

function AccessPolicyService.Start(_self: AccessPolicyService): () end

--[=[
	Registers a policy, disabled.

	@param policy AccessPolicy
	@return () -> () -- Removes the policy
]=]
function AccessPolicyService.RegisterPolicy(self: AccessPolicyService, policy: AccessPolicy.AccessPolicy): () -> ()
	assert(AccessPolicy.isAccessPolicy(policy), "Bad policy")

	local policyName = policy:GetPolicyName()
	assert(
		not self._policies:ContainsKey(policyName),
		`[AccessPolicyService] - Policy {policyName} is already registered`
	)

	local remove = self._policies:Set(policyName, policy)

	return function()
		-- Teardown order is not ours to control: a maid holding both this and the service bag may already
		-- have destroyed the registry underneath us. Unregistering a policy from a dead service is a
		-- no-op, not an error.
		if not self._alive then
			return
		end

		self._enabled[policyName] = nil
		for _, playerMaid in self._playerMaids do
			playerMaid[policyName] = nil
		end

		remove()
	end
end

--[=[
	Turns a policy on or off for every player at once. Enabling applies it to everyone already here;
	disabling tears it back down.

	@param policyName string
	@param enabled boolean
]=]
function AccessPolicyService.SetPolicyEnabled(self: AccessPolicyService, policyName: string, enabled: boolean): ()
	assert(type(policyName) == "string", "Bad policyName")
	assert(type(enabled) == "boolean", "Bad enabled")
	assert(self._policies:ContainsKey(policyName), `[AccessPolicyService] - No policy registered named {policyName}`)

	if self._enabled[policyName] == enabled then
		return
	end
	self._enabled[policyName] = enabled or nil

	for player, playerMaid in self._playerMaids do
		if enabled then
			playerMaid[policyName] = self:_applyPolicy(policyName, player)
		else
			playerMaid[policyName] = nil
		end
	end
end

--[=[
	@param policyName string
	@return boolean
]=]
function AccessPolicyService.IsPolicyEnabled(self: AccessPolicyService, policyName: string): boolean
	assert(type(policyName) == "string", "Bad policyName")

	return self._enabled[policyName] == true
end

--[=[
	@param policyName string
	@return AccessPolicy?
]=]
function AccessPolicyService.GetPolicy(self: AccessPolicyService, policyName: string): AccessPolicy.AccessPolicy?
	assert(type(policyName) == "string", "Bad policyName")

	return self._policies:Get(policyName)
end

--[=[
	@return { string }
]=]
function AccessPolicyService.GetPolicyNames(self: AccessPolicyService): { string }
	local names = self._policies:GetKeyList()
	table.sort(names)

	return names
end

--[=[
	Starts running the enabled policies for a player.

	Called by [AccessService] as players join, and callable directly by a test holding a mock. Idempotent.

	@param player Player
	@return () -> () -- Stops running policies for this player
]=]
function AccessPolicyService.AddPlayer(self: AccessPolicyService, player: Player): () -> ()
	assert(player, "Bad player")

	if not self._playerMaids[player] then
		local playerMaid = Maid.new()
		self._playerMaids[player] = playerMaid

		for policyName in self._enabled do
			playerMaid[policyName] = self:_applyPolicy(policyName, player)
		end
	end

	return function()
		self:RemovePlayer(player)
	end
end

--[=[
	@param player Player
]=]
function AccessPolicyService.RemovePlayer(self: AccessPolicyService, player: Player): ()
	assert(player, "Bad player")

	local playerMaid = self._playerMaids[player]
	if playerMaid then
		self._playerMaids[player] = nil
		playerMaid:DoCleaning()
	end
end

--[=[
	Every policy, whether it is running, and what it reads. A disabled policy is included -- knowing a
	consequence exists but is switched off is most of the answer to "why did nothing happen".

	@return { [string]: { policyName: string, realm: string, enabled: boolean, facts: { string }, features: { string } } }
]=]
function AccessPolicyService.GetDebugState(self: AccessPolicyService): { [string]: any }
	local described = {}

	for policyName, policy in self._policies do
		local state = policy:GetDebugState()
		state.enabled = self:IsPolicyEnabled(policyName)
		described[policyName] = state
	end

	return described
end

-- Builds the context a policy is applied with. Fact and feature access is scoped to what the policy
-- declared, so the declaration in the readout is the whole truth about its inputs.
function AccessPolicyService._applyPolicy(self: AccessPolicyService, policyName: string, player: Player): any
	local policy = assert(self._policies:Get(policyName), "No policy")

	-- Registered here, but not ours to run. Enabling a server policy from the client's registry must not
	-- half-enforce it locally.
	if not policy:RunsInRealm(RunService:IsServer()) then
		return nil
	end

	local context: AccessPolicy.AccessPolicyContext = {
		player = player,

		observeFact = function(factName: string): Observable.Observable<boolean?>
			assert(
				policy:DeclaresFact(factName),
				`[AccessPolicyService] - Policy {policyName} reads fact {factName} without declaring it. `
					.. `Add it to options.facts so a readout can say what this policy depends on.`
			)

			return self._accessDataService:ObserveFactReport(player, factName):Pipe({
				Rx.map(function(report)
					return report.value
				end) :: any,
				Rx.distinct() :: any,
			}) :: any
		end,

		observeFeature = function(feature: AccessFeature.AccessFeature, subject: any?): any
			assert(
				policy:DeclaresFeature(feature),
				`[AccessPolicyService] - Policy {policyName} reads a feature without declaring it. `
					.. `Add it to options.features so a readout can say what this policy depends on.`
			)

			return self._accessDataService:ObserveFeature(player, feature, subject)
		end,
	}

	return policy:Apply(context)
end

function AccessPolicyService.Destroy(self: AccessPolicyService): ()
	self._alive = false

	for _, playerMaid in self._playerMaids do
		playerMaid:DoCleaning()
	end
	table.clear(self._playerMaids :: any)

	self._maid:DoCleaning()
end

return AccessPolicyService
