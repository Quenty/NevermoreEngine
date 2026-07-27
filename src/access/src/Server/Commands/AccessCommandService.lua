--!strict
--[=[
	Cmdr commands for inspecting and overriding access.

	The point of the package is that when somebody says "I can't get in", one command tells you why:

	```
	> access-facts Quenty
	Quenty
	  isStaff = true (allowlist)
	    override         p10000   abstained
	    allowlist        p100     true       <-- decided
	    groupRank        p0       false
	```

	Every command here is admin-gated, because [CmdrService] gates every command it registers on
	[PermissionService] outside of Studio. Overriding a fact is granting an entitlement, so that gate is
	the whole reason overrides are safe to ship enabled.

	@server
	@class AccessCommandService
]=]

local require = require(script.Parent.loader).load(script)

local AccessCommandUtils = require("AccessCommandUtils")
local AccessDataService = require("AccessDataService")
local AccessPlayer = require("AccessPlayer")
local AccessPolicyService = require("AccessPolicyService")
local CmdrService = require("CmdrService")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local AccessCommandService = {}
AccessCommandService.ServiceName = "AccessCommandService"

export type AccessCommandService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_cmdrService: any,
		_accessDataService: AccessDataService.AccessDataService,
		_accessPolicyService: AccessPolicyService.AccessPolicyService,
		_accessPlayerBinder: any,
	},
	{} :: typeof({ __index = AccessCommandService })
))

--[[
	GOTCHA: keeps the LAST emission, not the first. A fact opens on unresolved before anything is looked
	up, so taking the first would print "unresolved" for everything however well resolved it is.
]]
local function readOnce(observable: any): any
	local captured = nil
	local subscription = observable:Subscribe(function(value)
		captured = value
	end)
	subscription:Destroy()

	return captured
end

function AccessCommandService.Init(self: AccessCommandService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._cmdrService = self._serviceBag:GetService(CmdrService)

	-- Internal
	self._accessDataService = self._serviceBag:GetService(AccessDataService) :: any
	self._accessPolicyService = self._serviceBag:GetService(AccessPolicyService) :: any
	self._accessPlayerBinder = self._serviceBag:GetService(AccessPlayer)
end

function AccessCommandService.Start(self: AccessCommandService): ()
	self._maid:GivePromise(self._cmdrService:PromiseCmdr()):Then(function(cmdr)
		AccessCommandUtils.registerTypes(cmdr, self._accessDataService, function()
			return self._accessPolicyService:GetPolicyNames()
		end)
		self:_registerCommands()
	end)
end

function AccessCommandService._registerCommands(self: AccessCommandService): ()
	self._cmdrService:RegisterCommand({
		Name = "access-facts",
		Description = "Shows every access fact for a player, with every layer and which one decided.",
		Group = "Access",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = "Players to inspect (e.g. . for yourself).",
			},
		},
	}, function(_context, players: { Player })
		return self:_render(players, function(player)
			local reports = readOnce(self._accessDataService:ObserveFactReports(player))
			if not reports then
				return "  (no facts registered)"
			end

			local factNames = {}
			for factName in reports do
				table.insert(factNames, factName)
			end
			table.sort(factNames)

			if #factNames == 0 then
				return "  (no facts registered)"
			end

			local lines = {}
			for _, factName in factNames do
				table.insert(lines, AccessCommandUtils.formatFactReport(reports[factName], "  "))
			end

			return table.concat(lines, "\n")
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "access-state",
		Description = "Prints everything known about a player's access: every feature verdict and every fact.",
		Group = "Access",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = "Players to dump (e.g. . for yourself).",
			},
			{
				Name = "Realm",
				Type = "accessRealm",
				Description = "server (default), client, or both to compare them.",
				Default = AccessCommandUtils.RealmValues.SERVER,
			},
		},
	}, function(_context, players: { Player }, realm: string)
		return self:_render(players, function(player)
			local blocks = {}

			if realm ~= AccessCommandUtils.RealmValues.CLIENT then
				table.insert(blocks, self:_labelRealm(realm, "SERVER", self:_collectState(player)))
			end

			if realm ~= AccessCommandUtils.RealmValues.SERVER then
				table.insert(blocks, self:_labelRealm(realm, "CLIENT", self:_collectClientState(player)))
			end

			return table.concat(blocks, "\n\n")
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "access-feature",
		Description = "Shows a feature's verdict for a player, and every fact it was reached from.",
		Group = "Access",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = "Players to inspect (e.g. . for yourself).",
			},
			{
				Name = "Feature",
				Type = "accessFeatureName",
				Description = "The feature to explain.",
			},
		},
	}, function(_context, players: { Player }, featureName: string)
		local feature = self._accessDataService:GetFeature(featureName)
		if not feature then
			return `No feature registered named {featureName}`
		end

		return self:_render(players, function(player)
			local report = readOnce(self._accessDataService:ObserveFeatureReport(player, feature))
			if not report then
				return "  (no verdict available)"
			end

			return `  {AccessCommandUtils.formatFeatureReport(report)}`
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "access-policies",
		Description = "Lists every access policy and whether it is running.",
		Group = "Access",
		Args = {},
	}, function(_context)
		return AccessCommandUtils.formatPolicies(self:_describePolicies())
	end)

	self._cmdrService:RegisterCommand({
		Name = "access-policy",
		Description = "Turns an access policy on or off for everybody.",
		Group = "Access",
		Args = {
			{
				Name = "Policy",
				Type = "accessPolicyName",
				Description = "The policy to toggle.",
			},
			{
				Name = "State",
				Type = "accessToggle",
				Description = "on or off.",
			},
		},
	}, function(_context, policyName: string, state: string)
		local enabled = state == AccessCommandUtils.ToggleValues.ON
		if not self._accessPolicyService:GetPolicy(policyName) then
			return `No policy registered named {policyName}`
		end

		self._accessPolicyService:SetPolicyEnabled(policyName, enabled)

		return `{policyName} is now {if enabled then "ENABLED" else "disabled"}.`
	end)

	self._cmdrService:RegisterCommand({
		Name = "access-override",
		Description = "Forces a fact for a player. Use 'unresolved' to force the not-yet-known state.",
		Group = "Access",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = "Players to override the fact for.",
			},
			{
				Name = "Fact",
				Type = "accessFactName",
				Description = "The fact to force.",
			},
			{
				Name = "Value",
				Type = "accessOverrideValue",
				Description = "true, false, or unresolved.",
			},
		},
	}, function(_context, players: { Player }, factName: string, value: string)
		local overrideValue = AccessCommandUtils.parseOverrideValue(value)

		for _, player in players do
			self._accessDataService:SetFactOverride(player, factName, overrideValue)
		end

		return `Set {factName} to {value} for {#players} player(s). It shows as its own layer in `
			.. `access-facts, so the real answer stays visible underneath.`
	end)

	self._cmdrService:RegisterCommand({
		Name = "access-clear-overrides",
		Description = "Clears every access fact override for a player.",
		Group = "Access",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = "Players to clear overrides for.",
			},
		},
	}, function(_context, players: { Player })
		for _, player in players do
			self._accessDataService:ClearFactOverrides(player)
		end

		return `Cleared overrides for {#players} player(s).`
	end)
end

function AccessCommandService._collectState(self: AccessCommandService, player: Player): string
	return AccessCommandUtils.formatCollectedPlayerState(
		AccessCommandUtils.collectPlayerState(self._accessDataService, self._accessPolicyService, player)
	)
end

--[[
	Runs the same collector the server just ran, on the client, so a difference between the two blocks is
	a real difference. A client that cannot answer is reported rather than hidden -- "their realm never
	got that far" is usually the answer to the complaint that prompted the command.
]]
function AccessCommandService._collectClientState(self: AccessCommandService, player: Player): string
	local accessPlayer = self._accessPlayerBinder:Get(player)
	if not accessPlayer then
		return "  (no AccessPlayer bound for this player yet)"
	end

	local ok, result = accessPlayer:PromiseClientAccessState():Yield()
	if not ok then
		return `  (client did not answer: {tostring(result)})`
	end

	return AccessCommandUtils.formatCollectedPlayerState(result)
end

function AccessCommandService._labelRealm(
	_self: AccessCommandService,
	realm: string,
	label: string,
	block: string
): string
	if realm ~= AccessCommandUtils.RealmValues.BOTH then
		return block
	end

	return `=== {label} ===\n{block}`
end

function AccessCommandService._describePolicies(self: AccessCommandService): { any }
	local policies = {}

	for _, policyName in self._accessPolicyService:GetPolicyNames() do
		local policy = self._accessPolicyService:GetPolicy(policyName)
		if policy then
			table.insert(policies, {
				policyName = policyName,
				enabled = self._accessPolicyService:IsPolicyEnabled(policyName),
				facts = policy:GetFactNames(),
			})
		end
	end

	return policies
end

function AccessCommandService._render(
	_self: AccessCommandService,
	players: { Player },
	describe: (Player) -> string
): string
	if #players == 0 then
		return "No players matched."
	end

	local blocks = {}
	for _, player in players do
		table.insert(blocks, `{player.Name}\n{describe(player)}`)
	end

	return table.concat(blocks, "\n\n")
end

function AccessCommandService.Destroy(self: AccessCommandService): ()
	self._maid:DoCleaning()
end

return AccessCommandService
