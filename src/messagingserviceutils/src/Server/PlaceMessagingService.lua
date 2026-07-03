--!strict
--[=[
    Provides a centralized messaging service for the current place, to other places.
    @class PlaceMessagingService
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Maid = require("Maid")
local MessagingServiceUtils = require("MessagingServiceUtils")
local Observable = require("Observable")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")
local StateStack = require("StateStack")

local LOG_DEBUG = false

local PlaceMessagingService = {}
PlaceMessagingService.ServiceName = "PlaceMessagingService"

export type PlaceMessagingService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_subscriptionTable: ObservableSubscriptionTable.ObservableSubscriptionTable<(any, PlacePacketMetadata)>,
		_connectionRequire: StateStack.StateStack<boolean>,
		_maid: Maid.Maid,
	},
	{} :: typeof({ __index = PlaceMessagingService })
))

export type PlaceAddress = {
	jobId: string,
	placeId: number,
}

type PlaceMessagingPacket = {
	topic: string,
	from: PlaceAddress,
	message: any,
}

export type PlacePacketMetadata = {
	sent: number, -- Same as the MessagingService timestamp
	topic: string,
	from: PlaceAddress,
}

function PlaceMessagingService.Init(self: PlaceMessagingService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._connectionRequire = self._maid:Add(StateStack.new(false, "boolean"))
	self._subscriptionTable = self._maid:Add(ObservableSubscriptionTable.new() :: any)
end

function PlaceMessagingService.Start(self: PlaceMessagingService): ()
	-- Subscribe as needed
	self._maid:GiveTask(self._connectionRequire
		:ObserveBrio(function(required)
			return required
		end)
		:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid = brio:ToMaid()
			local address = self:GetPlaceAddress()
			local topic = self:PlaceAddressToTopicString(address)

			if LOG_DEBUG then
				print(`[PlaceMessagingService] - Subscribing to global topic {topic}`)
			end

			maid:GiveTask(
				MessagingServiceUtils.promiseSubscribe(topic, function(data: MessagingServiceUtils.SubscriptionData)
					self:_handleIncomingPacket(data)
				end):Then(function(connection: RBXScriptConnection)
					maid:GiveTask(connection)
				end)
			)
		end))
end

function PlaceMessagingService._handleIncomingPacket(
	self: PlaceMessagingService,
	data: MessagingServiceUtils.SubscriptionData
): ()
	local packet: PlaceMessagingPacket = data.Data :: any

	if LOG_DEBUG then
		print(`[PlaceMessagingService] - Receipted {MessagingServiceUtils.toHumanReadable(packet)}`)
	end

	if type(packet) ~= "table" then
		warn("[PlaceMessagingService] - Received invalid packet on place messaging service")
		return
	end

	local topic = packet.topic
	if type(topic) ~= "string" then
		warn("[PlaceMessagingService] - Received invalid topic on place messaging service")
		return
	end

	local message = packet.message
	if message == nil then
		warn("[PlaceMessagingService] - Received nil message on place messaging service")
		return
	end

	local metadata: PlacePacketMetadata = {
		sent = data.Sent,
		topic = topic,
		from = packet.from,
	}
	self._subscriptionTable:Fire(packet.topic, packet.message, metadata)
end

--[=[
    Observes messages for the current place on the given topic

    The returned value should be the same as the message published.

    :::tip
    This observable will only be active while there is at least one active
    subscription to it. This is to help limit unnecessary load on MessagingService.
    :::

    @param topic string
    @return Observable<unknown>
]=]
function PlaceMessagingService.ObserveMessages(
	self: PlaceMessagingService,
	topic: string
): Observable.Observable<any, PlacePacketMetadata>
	local observable = self._subscriptionTable:Observe(topic)
	return Observable.new(function(sub)
		local inner = observable:Subscribe(sub:GetFireFailComplete())
		local removePush = self._connectionRequire:PushState(true)

		if LOG_DEBUG then
			print(`[PlaceMessagingService] - Subscribing to internal {topic}`)
		end

		return function()
			removePush()
			inner:Destroy()
		end
	end) :: any
end

--[=[
    Sends a message to the given place and job

    @param placeId number
    @param jobId string
    @param topic string
    @param message any
    @return Promise<()>
]=]
function PlaceMessagingService.SendMessage(
	self: PlaceMessagingService,
	placeId: number,
	jobId: string,
	topic: string,
	message: any
): Promise.Promise<()>
	local address = self:PlaceAndJobToServerAddress(placeId, jobId)
	return self:SendMessageToAddress(address, topic, message)
end

--[=[
    Sends a message to the given place address

    @param address PlaceAddress
    @param topic string
    @param message any
    @return Promise<()>
]=]
function PlaceMessagingService.SendMessageToAddress(
	self: PlaceMessagingService,
	address: PlaceAddress,
	topic: string,
	message: any
): Promise.Promise<()>
	local packet: PlaceMessagingPacket = {
		topic = topic,
		from = self:GetPlaceAddress(),
		message = message,
	}
	local addressString = self:PlaceAddressToTopicString(address)

	if LOG_DEBUG then
		print(`[PlaceMessagingService] - To {addressString} sending {MessagingServiceUtils.toHumanReadable(packet)}`)
	end

	return self._maid:GivePromise(MessagingServiceUtils.promisePublish(addressString, packet))
end

--[=[
    Gets the current place address

    @return PlaceAddress
]=]
function PlaceMessagingService.GetPlaceAddress(self: PlaceMessagingService): PlaceAddress
	local jobId = game.JobId
	if jobId == "" and RunService:IsStudio() then
		jobId = "studio"
	end

	return self:PlaceAndJobToServerAddress(game.PlaceId, jobId)
end

--[=[
    Converts a place address to a topic string

    @param address PlaceAddress
    @return string
]=]
function PlaceMessagingService.PlaceAddressToTopicString(_self: PlaceMessagingService, address: PlaceAddress): string
	return `PlaceMessagingService_{address.placeId}_{address.jobId}`
end

--[=[
    Converts a placeId and jobId to a place address

    @param placeId number
    @param jobId string
    @return PlaceAddress
]=]
function PlaceMessagingService.PlaceAndJobToServerAddress(
	_self: PlaceMessagingService,
	placeId: number,
	jobId: string
): PlaceAddress
	return {
		placeId = placeId,
		jobId = jobId,
	}
end

function PlaceMessagingService.Destroy(self: PlaceMessagingService)
	self._maid:DoCleaning()
	self._maid = nil :: any
end

return PlaceMessagingService
