--!strict
--[=[
	Server half of the observable relay. Owns the bound observable factory for a single
	member, turns client subscribe requests into live subscriptions, and forwards each
	emission back down the reserved remote event.

	Requests arrive from untrusted clients, so every field off the wire is validated here
	and each player is capped to
	[RemotingObservableConstants.MAX_SUBSCRIPTIONS_PER_PLAYER] concurrent subscriptions.

	@class RemotingObservableServerRelay
	@private
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Maid = require("Maid")
local Observable = require("Observable")
local RemotingObservableConstants = require("RemotingObservableConstants")

local RemotingObservableServerRelay = {}
RemotingObservableServerRelay.ClassName = "RemotingObservableServerRelay"
RemotingObservableServerRelay.__index = RemotingObservableServerRelay

export type ObservableFactory = (player: Player, ...any) -> Observable.Observable<...any>

export type RemotingObservableServerRelay = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_remoting: any,
		_memberName: string,
		_reservedMemberName: string,
		_factory: ObservableFactory,
		-- Maid values are held as any: a Maid stored behind a table index type loses its
		-- generic methods and stops type checking at the call site
		_subscriptions: { [Player]: { [string]: any } },
		_subscriptionCount: { [Player]: number },
	},
	{} :: typeof({ __index = RemotingObservableServerRelay })
))

--[=[
	Constructs a new server relay for the member and starts listening for requests.

	@param remoting Remoting
	@param memberName string
	@param factory (player: Player, ...any) -> Observable
	@return RemotingObservableServerRelay
]=]
function RemotingObservableServerRelay.new(
	remoting: any,
	memberName: string,
	factory: ObservableFactory
): RemotingObservableServerRelay
	local self: RemotingObservableServerRelay = setmetatable({} :: any, RemotingObservableServerRelay)

	self._maid = Maid.new()
	self._remoting = assert(remoting, "No remoting")
	self._memberName = assert(memberName, "No memberName")
	self._reservedMemberName = memberName .. RemotingObservableConstants.RESERVED_MEMBER_SUFFIX
	self._factory = assert(factory, "No factory")
	self._subscriptions = {}
	self._subscriptionCount = {}

	self._maid:GiveTask(self._remoting:Connect(self._reservedMemberName, function(player, opcode, subscriptionKey, ...)
		self:_handleRequest(player, opcode, subscriptionKey, ...)
	end))

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		self:_cleanupPlayer(player)
	end))

	return self
end

function RemotingObservableServerRelay._handleRequest(
	self: RemotingObservableServerRelay,
	player: Player,
	opcode: any,
	subscriptionKey: any,
	...
)
	if typeof(player) ~= "Instance" then
		return
	end

	if type(subscriptionKey) ~= "string" then
		return
	end

	if #subscriptionKey == 0 or #subscriptionKey > RemotingObservableConstants.MAX_SUBSCRIPTION_KEY_LENGTH then
		return
	end

	if opcode == RemotingObservableConstants.OPCODE_SUBSCRIBE then
		self:_handleSubscribe(player, subscriptionKey, ...)
	elseif opcode == RemotingObservableConstants.OPCODE_UNSUBSCRIBE then
		self:_cleanupSubscription(player, subscriptionKey)
	end
end

function RemotingObservableServerRelay._handleSubscribe(
	self: RemotingObservableServerRelay,
	player: Player,
	subscriptionKey: string,
	...
)
	local playerSubscriptions = self._subscriptions[player]
	if not playerSubscriptions then
		playerSubscriptions = {}
		self._subscriptions[player] = playerSubscriptions
		self._subscriptionCount[player] = 0
	end

	if playerSubscriptions[subscriptionKey] then
		return
	end

	if self._subscriptionCount[player] >= RemotingObservableConstants.MAX_SUBSCRIPTIONS_PER_PLAYER then
		self:_send(player, RemotingObservableConstants.OPCODE_FAIL, subscriptionKey, "Subscription limit reached")
		return
	end

	local ok, observable = pcall(self._factory, player, ...)
	if not ok then
		warn(
			string.format(
				"[RemotingObservableServerRelay] - Observable factory for %q errored: %s",
				self._memberName,
				tostring(observable)
			)
		)
		self:_send(player, RemotingObservableConstants.OPCODE_FAIL, subscriptionKey, "Failed to construct observable")
		return
	end

	if not Observable.isObservable(observable) then
		warn(
			string.format(
				"[RemotingObservableServerRelay] - Observable factory for %q returned a non-observable",
				self._memberName
			)
		)
		self:_send(player, RemotingObservableConstants.OPCODE_FAIL, subscriptionKey, "Failed to construct observable")
		return
	end

	local subscriptionMaid = Maid.new()
	playerSubscriptions[subscriptionKey] = subscriptionMaid
	self._subscriptionCount[player] += 1

	subscriptionMaid:GiveTask(function()
		local subscriptions = self._subscriptions[player]
		if subscriptions and subscriptions[subscriptionKey] then
			subscriptions[subscriptionKey] = nil
			self._subscriptionCount[player] -= 1
		end
	end)

	local subscription = (observable :: any):Subscribe(function(...)
		self:_send(player, RemotingObservableConstants.OPCODE_FIRE, subscriptionKey, ...)
	end, function(...)
		self:_send(player, RemotingObservableConstants.OPCODE_FAIL, subscriptionKey, ...)
		self:_cleanupSubscription(player, subscriptionKey)
	end, function()
		self:_send(player, RemotingObservableConstants.OPCODE_COMPLETE, subscriptionKey)
		self:_cleanupSubscription(player, subscriptionKey)
	end)

	-- A source that completes synchronously has already torn the entry down by now
	if playerSubscriptions[subscriptionKey] then
		subscriptionMaid:GiveTask(subscription)
	else
		subscription:Destroy()
	end
end

function RemotingObservableServerRelay._send(
	self: RemotingObservableServerRelay,
	player: Player,
	opcode: number,
	subscriptionKey: string,
	...
)
	self._remoting:FireClient(self._reservedMemberName, player, opcode, subscriptionKey, ...)
end

function RemotingObservableServerRelay._cleanupSubscription(
	self: RemotingObservableServerRelay,
	player: Player,
	subscriptionKey: string
)
	local playerSubscriptions = self._subscriptions[player]
	if not playerSubscriptions then
		return
	end

	local subscriptionMaid = playerSubscriptions[subscriptionKey]
	if not subscriptionMaid then
		return
	end

	subscriptionMaid:DoCleaning()
end

function RemotingObservableServerRelay._cleanupPlayer(self: RemotingObservableServerRelay, player: Player)
	local playerSubscriptions = self._subscriptions[player]
	if not playerSubscriptions then
		return
	end

	self._subscriptions[player] = nil
	self._subscriptionCount[player] = nil

	for _, subscriptionMaid in playerSubscriptions do
		subscriptionMaid:DoCleaning()
	end
end

--[=[
	Completes every live subscription and stops listening for requests.
]=]
function RemotingObservableServerRelay.Destroy(self: RemotingObservableServerRelay)
	for player, playerSubscriptions in self._subscriptions do
		for subscriptionKey, subscriptionMaid in playerSubscriptions do
			self:_send(player, RemotingObservableConstants.OPCODE_COMPLETE, subscriptionKey)
			subscriptionMaid:DoCleaning()
		end
	end

	table.clear(self._subscriptions)
	table.clear(self._subscriptionCount)

	self._maid:DoCleaning()
	setmetatable(self :: any, nil)
end

return RemotingObservableServerRelay
