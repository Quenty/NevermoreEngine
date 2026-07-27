--!strict
--[=[
	Replicates every fact's server answer to the player it is about.

	Unconditional by design: a fact does not choose whether to replicate, only what the client should do
	with what arrives (see [AccessFactServerOverrideBehavior]). A fact that could opt out of replicating
	would fail as silence on the client, which is the hardest kind of failure to notice and to explain.

	Authoritative in the sense that matters: it sends what the server resolved and never reads anything a
	client supplied. There is no inbound path here at all.

	@server
	@class AccessReplicationService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessDataService = require("AccessDataService")
local Maid = require("Maid")
local Remoting = require("Remoting")
local ServiceBag = require("ServiceBag")

-- Named once here and matched by the client. A shared constants module for two strings buys nothing
-- that a wrong name would not announce immediately as total silence.
local REMOTING_NAME = "AccessFactReplication"

local AccessReplicationService = {}
AccessReplicationService.ServiceName = "AccessReplicationService"

export type AccessReplicationService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_accessDataService: any,
		_remoting: any,
		_playerMaids: { [any]: any },
		_sentByPlayer: { [any]: { [string]: { value: boolean?, abstained: boolean? } } },
	},
	{} :: typeof({ __index = AccessReplicationService })
))

function AccessReplicationService.Init(self: AccessReplicationService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._accessDataService = self._serviceBag:GetService(AccessDataService)
	self._remoting = self._maid:Add(Remoting.Server.new(ReplicatedStorage, REMOTING_NAME))
	self._remoting.SetFactValue:DeclareEvent()

	-- The client asks for everything once on start. Without it, a client that connects after the server
	-- has already sent hears nothing until the next change -- which for a fact that never changes again
	-- is never.
	self._maid:GiveTask(self._remoting.GetFactValues:Bind(function(player: Player)
		return self:GetFactValues(player)
	end))

	self._playerMaids = {}
	self._sentByPlayer = {}
end

function AccessReplicationService.Start(self: AccessReplicationService): ()
	self._maid:GiveTask(Players.PlayerAdded:Connect(function(player: Player)
		self:AddPlayer(player)
	end))
	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player: Player)
		self:RemovePlayer(player)
	end))

	for _, player in Players:GetPlayers() do
		self:AddPlayer(player)
	end
end

--[=[
	Starts replicating every registered fact to this player, and keeps doing so as facts change.

	Public because it is also how a test drives replication without a real client on the other end.

	@param player Player
]=]
function AccessReplicationService.AddPlayer(self: AccessReplicationService, player: Player): ()
	assert(player, "Bad player")

	if self._playerMaids[player] then
		return
	end

	local playerMaid = Maid.new()
	self._playerMaids[player] = playerMaid
	self._sentByPlayer[player] = {}

	playerMaid:GiveTask(self._accessDataService:ObserveFactReports(player):Subscribe(function(reports: any)
		for factName, report in reports do
			-- decidedBy nil means every layer abstained: nobody here can answer it either. Sent as its own
			-- state so the client can tell that from a value still in flight.
			self:_sendFactValue(player, factName, report.value, report.decidedBy == nil)
		end
	end))
end

--[=[
	Every fact this server currently resolves for a player, as a plain map. What a joining client asks
	for, and what a test can assert against without watching the wire.

	@param player Player
	@return { [string]: { value: boolean? } }
]=]
function AccessReplicationService.GetFactValues(
	self: AccessReplicationService,
	player: Player
): { [string]: { value: boolean?, abstained: boolean? } }
	assert(player, "Bad player")

	local values: { [string]: { value: boolean?, abstained: boolean? } } = {}
	local reports = nil
	local subscription = self._accessDataService:ObserveFactReports(player):Subscribe(function(value)
		reports = value
	end)
	subscription:Destroy()

	for factName, report in reports or {} do
		-- Boxed, so a fact the server resolves as unresolved is still transmitted as *an answer* rather
		-- than vanishing from the table the way a nil would.
		values[factName] = { value = report.value, abstained = report.decidedBy == nil }
	end

	-- Anything sent as part of the snapshot does not need sending again as a change.
	local sent = self._sentByPlayer[player]
	if sent then
		for factName, box in values do
			sent[factName] = { value = box.value, abstained = box.abstained }
		end
	end

	return values
end

--[=[
	@param player Player
]=]
function AccessReplicationService.RemovePlayer(self: AccessReplicationService, player: Player): ()
	assert(player, "Bad player")

	local playerMaid = self._playerMaids[player]
	if playerMaid then
		self._playerMaids[player] = nil
		self._sentByPlayer[player] = nil
		playerMaid:DoCleaning()
	end
end

-- Only what moved. A fact reports on every recomputation, and most of those carry the same answer; a
-- remote call per recomputation would be noise on the wire and noise in any readout of it.
function AccessReplicationService._sendFactValue(
	self: AccessReplicationService,
	player: Player,
	factName: string,
	value: boolean?,
	abstained: boolean?
): ()
	local sent = self._sentByPlayer[player]
	if not sent then
		return
	end

	local box = sent[factName]
	if box and box.value == value and box.abstained == abstained then
		return
	end
	-- Boxed so that "sent unresolved" is remembered as having been sent at all.
	sent[factName] = { value = value, abstained = abstained }

	self._remoting.SetFactValue:FireClient(player, factName, value, abstained)
end

function AccessReplicationService.Destroy(self: AccessReplicationService): ()
	for _, playerMaid in self._playerMaids do
		playerMaid:DoCleaning()
	end
	table.clear(self._playerMaids :: any)
	table.clear(self._sentByPlayer :: any)

	self._maid:DoCleaning()
end

return AccessReplicationService
