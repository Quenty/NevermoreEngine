--!strict
--[=[
	In-memory stand-in for Roblox's `MessagingService` used by tests. It provides in-process
	loopback: a [MessagingServiceMock.PublishAsync] on a topic delivers the message to every
	current subscriber of that topic on the next task step, shaped exactly like the real
	`MessagingService` delivers it (`{ Data = message, Sent = <number> }`).

	Messages are round-tripped through JSON on delivery (mimicking the real serialization), so
	aliasing bugs surface the same way they would against the real service.

	It is injected into a [PlaceMessagingService] via
	[PlaceMessagingService.SetRobloxMessagingService] so tests never touch the real
	`MessagingService`.

	```lua
	local messagingService = MessagingServiceMock.new()
	placeMessagingService:SetRobloxMessagingService(messagingService)
	```

	@server
	@class MessagingServiceMock
]=]

local HttpService = game:GetService("HttpService")

local MessagingServiceMock = {}
MessagingServiceMock.ClassName = "MessagingServiceMock"
MessagingServiceMock.__index = MessagingServiceMock

type SubscriptionData = {
	Data: any,
	Sent: number,
}

export type MessagingServiceMock = typeof(setmetatable(
	{} :: {
		_subscribers: { [string]: { [number]: (SubscriptionData) -> () } },
		_nextConnectionId: number,
	},
	{} :: typeof({ __index = MessagingServiceMock })
))

local function roundTrip(message: any): any
	if type(message) ~= "table" then
		return message
	end

	return HttpService:JSONDecode(HttpService:JSONEncode(message))
end

--[=[
	Returns whether the given value is a [MessagingServiceMock].

	@param value any
	@return boolean
]=]
function MessagingServiceMock.isMessagingServiceMock(value: any): boolean
	return type(value) == "table" and getmetatable(value) == MessagingServiceMock
end

--[=[
	Constructs a new MessagingServiceMock.

	@return MessagingServiceMock
]=]
function MessagingServiceMock.new(): MessagingServiceMock
	local self = setmetatable({}, MessagingServiceMock)

	self._subscribers = {}
	self._nextConnectionId = 0

	return self
end

--[=[
	Mimics `MessagingService:PublishAsync`. Delivers the message to every current subscriber of the
	topic on the next task step, shaped as `{ Data = message, Sent = <number> }`. The message is
	round-tripped through JSON, mimicking the real service's serialization.

	@param topic string
	@param message any?
]=]
function MessagingServiceMock.PublishAsync(self: MessagingServiceMock, topic: string, message: any?): ()
	assert(type(topic) == "string", "Bad topic")

	local subscribers = self._subscribers[topic]
	if not subscribers then
		return
	end

	-- Snapshot so a subscriber that (un)subscribes during delivery does not affect this fan-out.
	local callbacks = {}
	for _, callback in subscribers do
		table.insert(callbacks, callback)
	end

	local sent = os.time()
	for _, callback in callbacks do
		task.defer(function()
			callback({
				Data = roundTrip(message),
				Sent = sent,
			})
		end)
	end
end

--[=[
	Mimics `MessagingService:SubscribeAsync`. Returns a connection-like object that removes the
	subscriber when disconnected (or destroyed by a [Maid]).

	@param topic string
	@param callback (SubscriptionData) -> ()
	@return { Connected: boolean, Disconnect: () -> (), Destroy: () -> () }
]=]
function MessagingServiceMock.SubscribeAsync(
	self: MessagingServiceMock,
	topic: string,
	callback: (SubscriptionData) -> ()
): any
	assert(type(topic) == "string", "Bad topic")
	assert(type(callback) == "function", "Bad callback")

	local subscribers = self._subscribers[topic]
	if not subscribers then
		subscribers = {}
		self._subscribers[topic] = subscribers
	end

	self._nextConnectionId += 1
	local connectionId = self._nextConnectionId
	subscribers[connectionId] = callback

	local connection
	local function disconnect()
		if not connection.Connected then
			return
		end
		connection.Connected = false

		local topicSubscribers = self._subscribers[topic]
		if topicSubscribers then
			topicSubscribers[connectionId] = nil
			if next(topicSubscribers) == nil then
				self._subscribers[topic] = nil
			end
		end
	end

	connection = {
		Connected = true,
		Disconnect = disconnect,
		Destroy = disconnect,
	}

	return connection
end

return MessagingServiceMock
