--!strict
--[=[
	Client half of the observable relay. Hands out cold observables for a single member and
	routes emissions coming down the reserved remote event back to the subscription that
	asked for them.

	Outbound messages go through the raw remote event rather than
	[Remoting.PromiseFireServer] on purpose. That path resolves synchronously once the
	remote exists but asynchronously before it does, so a subscribe issued while waiting
	could be overtaken by the unsubscribe that follows it and strand a live subscription on
	the server. Here the live subscription table is the queue: nothing is sent until the
	remote resolves, and whatever is still subscribed at that point is sent in one pass.

	@class RemotingObservableClientRelay
	@private
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Observable = require("Observable")
local RemotingObservableConstants = require("RemotingObservableConstants")

local SUBSCRIPTION_KEY_OWNER = "c"

local RemotingObservableClientRelay = {}
RemotingObservableClientRelay.ClassName = "RemotingObservableClientRelay"
RemotingObservableClientRelay.__index = RemotingObservableClientRelay

-- The subscription is held as any: a Subscription stored behind a table index type loses
-- its generic methods and stops type checking at the call site
type PendingSubscription = {
	subscription: any,
	args: { n: number, [number]: any },
}

export type RemotingObservableClientRelay = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_remoting: any,
		_memberName: string,
		_reservedMemberName: string,
		_subscriptions: { [string]: PendingSubscription },
		_nextSubscriptionId: number,
		_remoteEvent: (RemoteEvent | BindableEvent)?,
	},
	{} :: typeof({ __index = RemotingObservableClientRelay })
))

--[=[
	Constructs a new client relay for the member and starts listening for emissions.

	@param remoting Remoting
	@param memberName string
	@return RemotingObservableClientRelay
]=]
function RemotingObservableClientRelay.new(remoting: any, memberName: string): RemotingObservableClientRelay
	local self: RemotingObservableClientRelay = setmetatable({} :: any, RemotingObservableClientRelay)

	self._maid = Maid.new()
	self._remoting = assert(remoting, "No remoting")
	self._memberName = assert(memberName, "No memberName")
	self._reservedMemberName = memberName .. RemotingObservableConstants.RESERVED_MEMBER_SUFFIX
	self._subscriptions = {}
	self._nextSubscriptionId = 0

	self._maid:GiveTask(self._remoting:Connect(self._reservedMemberName, function(opcode, subscriptionKey, ...)
		self:_handleMessage(opcode, subscriptionKey, ...)
	end))

	self._maid:GiveTask(
		self._remoting:_observeUpstreamRemoteEventBrio(self._reservedMemberName):Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid, remoteEvent = brio:ToMaidAndValue()

			self._remoteEvent = remoteEvent
			self:_sendLiveSubscriptions()

			maid:GiveTask(function()
				if self._remoteEvent == remoteEvent then
					self._remoteEvent = nil
				end
			end)
		end)
	)

	return self
end

--[=[
	Returns a cold observable. Each subscription opens its own stream on the server, so
	share the result if more than one consumer needs it.

	@param ... any
	@return Observable<...any>
]=]
function RemotingObservableClientRelay.Observe(self: RemotingObservableClientRelay, ...): Observable.Observable<...any>
	local args = table.pack(...)

	return Observable.new(function(subscription)
		local subscriptionKey = self:_nextSubscriptionKey()
		local maid = Maid.new()

		self._subscriptions[subscriptionKey] = {
			subscription = subscription :: any,
			args = args,
		}

		self:_send(RemotingObservableConstants.OPCODE_SUBSCRIBE, subscriptionKey, table.unpack(args, 1, args.n))

		maid:GiveTask(function()
			-- Already cleared when the server ended the stream, so there is nothing to cancel
			if self._subscriptions[subscriptionKey] then
				self._subscriptions[subscriptionKey] = nil
				self:_send(RemotingObservableConstants.OPCODE_UNSUBSCRIBE, subscriptionKey)
			end
		end)

		return maid
	end) :: any
end

function RemotingObservableClientRelay._handleMessage(
	self: RemotingObservableClientRelay,
	opcode: any,
	subscriptionKey: any,
	...
)
	if type(subscriptionKey) ~= "string" then
		return
	end

	local entry = self._subscriptions[subscriptionKey]
	if not entry then
		return
	end

	if opcode == RemotingObservableConstants.OPCODE_FIRE then
		if entry.subscription:IsPending() then
			entry.subscription:Fire(...)
		end
	elseif opcode == RemotingObservableConstants.OPCODE_COMPLETE then
		self._subscriptions[subscriptionKey] = nil
		if entry.subscription:IsPending() then
			entry.subscription:Complete()
		end
	elseif opcode == RemotingObservableConstants.OPCODE_FAIL then
		self._subscriptions[subscriptionKey] = nil
		if entry.subscription:IsPending() then
			entry.subscription:Fail(...)
		end
	end
end

function RemotingObservableClientRelay._sendLiveSubscriptions(self: RemotingObservableClientRelay)
	for subscriptionKey, entry in self._subscriptions do
		self:_send(
			RemotingObservableConstants.OPCODE_SUBSCRIBE,
			subscriptionKey,
			table.unpack(entry.args, 1, entry.args.n)
		)
	end
end

function RemotingObservableClientRelay._send(self: RemotingObservableClientRelay, opcode: number, ...)
	local remoteEvent = self._remoteEvent
	if not remoteEvent then
		return
	end

	self._remoting:_fireUpstreamRemoteEvent(remoteEvent, opcode, ...)
end

function RemotingObservableClientRelay._nextSubscriptionKey(self: RemotingObservableClientRelay): string
	self._nextSubscriptionId += 1

	return string.format("%s%d", SUBSCRIPTION_KEY_OWNER, self._nextSubscriptionId)
end

--[=[
	Completes every live subscription and stops listening for emissions.
]=]
function RemotingObservableClientRelay.Destroy(self: RemotingObservableClientRelay)
	local subscriptions = self._subscriptions
	self._subscriptions = {}

	for _, entry in subscriptions do
		if entry.subscription:IsPending() then
			entry.subscription:Complete()
		end
	end

	self._maid:DoCleaning()
	setmetatable(self :: any, nil)
end

return RemotingObservableClientRelay
