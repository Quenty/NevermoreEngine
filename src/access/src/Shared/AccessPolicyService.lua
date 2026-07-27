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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AccessDataService = require("AccessDataService")
local AccessFactNames = require("AccessFactNames")
local AccessFeature = require("AccessFeature")
local AccessKickPolicy = require("AccessKickPolicy")
local AccessPolicy = require("AccessPolicy")
local AccessPolicyContextUtils = require("AccessPolicyContextUtils")
local AccessPolicyNames = require("AccessPolicyNames")
local AccessPolicyServiceInterface = require("AccessPolicyServiceInterface")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableMap = require("ObservableMap")
local Promise = require("Promise")
local Rx = require("Rx")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")

local AccessPolicyService = {}
AccessPolicyService.ServiceName = "AccessPolicyService"

export type AccessPolicyService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_tieRealmService: any,
		_accessDataService: AccessDataService.AccessDataService,
		_policies: any,
		_enabled: any,
		-- One maid per player, holding one task per enabled policy, keyed by policy name so a policy can be
		-- switched off for everyone without disturbing the others.
		_playerMaids: { [any]: any },
		_alive: boolean,
	},
	{} :: typeof({ __index = AccessPolicyService })
))

function AccessPolicyService.Init(self: AccessPolicyService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()
	self._tieRealmService = self._serviceBag:GetService(TieRealmService) :: any

	self._accessDataService = self._serviceBag:GetService(AccessDataService) :: any
	local policies = ObservableMap.new()
	self._policies = policies :: any
	self._maid:GiveTask(policies)
	local enabled = ObservableMap.new()
	self._enabled = enabled :: any
	self._maid:GiveTask(enabled)
	self._playerMaids = {}
	self._alive = true

	self:_registerBuiltInPolicies()
end

--[[
	Registered in both realms so the name exists everywhere, and disabled so shipping one does not switch
	it on. A game that wants different wording registers its own and leaves this one off.
]]
function AccessPolicyService._registerBuiltInPolicies(self: AccessPolicyService): ()
	self._maid:GiveTask(
		self:RegisterPolicy(
			AccessKickPolicy.whenFactIs(
				self._serviceBag,
				AccessPolicyNames.KICK_ON_NON_ADMIN,
				AccessFactNames.PLAYER_IS_ADMIN,
				false,
				{ message = "This place is currently limited to the development team." }
			)
		)
	)
end

function AccessPolicyService.Start(self: AccessPolicyService): ()
	-- Owned here rather than left to an entry point. A policy application is running code -- a
	-- subscription, a connection, a kick timer -- and leaking one past the session it belonged to is the
	-- kind of bug that only shows up as a server slowly filling with work for people who left.
	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player: Player)
		self:RemovePlayer(player)
	end))

	-- Same adornee as AccessDataServiceInterface: this is a singleton, and ReplicatedStorage is the one
	-- instance both realms already agree on.
	self._maid:GiveTask(
		AccessPolicyServiceInterface:Implement(ReplicatedStorage, self :: any, self._tieRealmService:GetTieRealm())
	)
end

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

	if self:IsPolicyEnabled(policyName) == enabled then
		return
	end
	self._enabled:Set(policyName, enabled or nil)

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

	return self._enabled:Get(policyName) == true
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
	Whether a policy is running, live. The registry changes at runtime -- a console command flips one,
	a game registers another -- so anything rendering policy state wants this rather than a snapshot it
	has to remember to refresh.

	@param policyName string
	@return Observable<boolean>
]=]
function AccessPolicyService.ObserveIsPolicyEnabled(
	self: AccessPolicyService,
	policyName: string
): Observable.Observable<boolean>
	assert(type(policyName) == "string", "Bad policyName")

	return self._enabled:ObserveAtKey(policyName):Pipe({
		Rx.map(function(value: boolean?)
			return value == true
		end) :: any,
		Rx.distinct() :: any,
	}) :: any
end

--[=[
	Every registered policy name, live.

	@return Observable<{ string }>
]=]
function AccessPolicyService.ObservePolicyNames(self: AccessPolicyService): Observable.Observable<{ string }>
	return self._policies:ObserveKeyList() :: any
end

--[=[
	Which policies read this fact.

	The reverse of [AccessPolicy.GetFactNames], and the question you actually have in a bug report:
	somebody's fact just flipped, so what acts on it? Declared inputs are what make this answerable at
	all -- a policy that read facts without declaring them would be invisible here.

	@param factName string
	@return { string }
]=]
function AccessPolicyService.GetPolicyNamesReadingFact(self: AccessPolicyService, factName: string): { string }
	assert(type(factName) == "string", "Bad factName")

	local names = {}
	for _, policyName in self._policies:GetKeyList() do
		if self._policies:Get(policyName):DeclaresFact(factName) then
			table.insert(names, policyName)
		end
	end
	table.sort(names)

	return names
end

--[=[
	Which policies read this feature.

	@param feature AccessFeature
	@return { string }
]=]
function AccessPolicyService.GetPolicyNamesReadingFeature(
	self: AccessPolicyService,
	feature: AccessFeature.AccessFeature
): { string }
	assert(AccessFeature.isAccessFeature(feature), "Bad feature")

	local names = {}
	for _, policyName in self._policies:GetKeyList() do
		if self._policies:Get(policyName):DeclaresFeature(feature) then
			table.insert(names, policyName)
		end
	end
	table.sort(names)

	return names
end

--[=[
	Whether a policy is actually running against this player right now.

	Three things have to be true and each fails differently, which is why asking
	[AccessPolicyService.IsPolicyEnabled] alone misleads: the policy is enabled, this realm is the one it
	runs in, and the player is being tracked at all.

	@param player Player
	@param policyName string
	@return boolean
]=]
function AccessPolicyService.IsPolicyActiveForPlayer(
	self: AccessPolicyService,
	player: Player,
	policyName: string
): boolean
	assert(player, "Bad player")
	assert(type(policyName) == "string", "Bad policyName")

	local policy = self._policies:Get(policyName)

	return policy ~= nil
		and self:IsPolicyEnabled(policyName)
		and policy:RunsInRealm(RunService:IsServer())
		and self._playerMaids[player] ~= nil
end

--[=[
	Whether a policy is *active* for this player, live.

	The naming across this service is deliberate and worth knowing: **enabled** is the global switch, and
	**active** is enabled *and* the right realm *and* this player being tracked. Everything scoped to one
	player says `ForPlayer`, so which of the two a method means is readable at the call site rather than
	something you have to remember.

	@param player Player
	@param policyName string
	@return Observable<boolean>
]=]
function AccessPolicyService.ObserveIsPolicyActiveForPlayer(
	self: AccessPolicyService,
	player: Player,
	policyName: string
): Observable.Observable<boolean>
	assert(player, "Bad player")

	return self:ObserveIsPolicyEnabled(policyName):Pipe({
		Rx.map(function()
			return self:IsPolicyActiveForPlayer(player, policyName)
		end) :: any,
		Rx.distinct() :: any,
	}) :: any
end

--[=[
	Settles once the policy is active for this player. Never resolves false -- a caller waiting on a policy
	wants to know when it starts, and "not yet" is not an outcome worth settling on.

	@param player Player
	@param policyName string
	@return Promise<boolean>
]=]
function AccessPolicyService.PromiseIsPolicyActiveForPlayer(
	self: AccessPolicyService,
	player: Player,
	policyName: string
): Promise.Promise<boolean>
	return Rx.toPromise(self:ObserveIsPolicyActiveForPlayer(player, policyName):Pipe({
		Rx.where(function(isActive: boolean)
			return isActive
		end) :: any,
	}) :: any) :: any
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

		for _, policyName in self._enabled:GetKeyList() do
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

	for _, policyName in self._policies:GetKeyList() do
		local state = self._policies:Get(policyName):GetDebugState()
		state.enabled = self:IsPolicyEnabled(policyName)
		described[policyName] = state
	end

	return described
end

--[[
	Fact and feature access is scoped to what the policy declared, so the declaration in the readout is
	the whole truth about its inputs.
]]
function AccessPolicyService._applyPolicy(self: AccessPolicyService, policyName: string, player: Player): any
	local policy = assert(self._policies:Get(policyName), "No policy")

	-- Registered here, but not ours to run. Enabling a server policy from the client's registry must not
	-- half-enforce it locally.
	if not policy:RunsInRealm(RunService:IsServer()) then
		return nil
	end

	local context = AccessPolicyContextUtils.create({
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
	})

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
