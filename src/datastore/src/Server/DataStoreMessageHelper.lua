--!strict
--[=[
    @class DataStoreMessageHelper
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local MessagingServiceUtils = require("MessagingServiceUtils")
local PlaceMessagingService = require("PlaceMessagingService")
local Promise = require("Promise")
local PromiseMaidUtils = require("PromiseMaidUtils")
local ServiceBag = require("ServiceBag")

local DEBUG_LOG = false

local DataStoreMessageHelper = setmetatable({}, BaseObject)
DataStoreMessageHelper.ClassName = "DataStoreMessageHelper"
DataStoreMessageHelper.__index = DataStoreMessageHelper

export type DataStoreMessageHelper =
	typeof(setmetatable(
		{} :: {
			_dataStore: any,
			_serviceBag: ServiceBag.ServiceBag,
			_placeMessagingService: PlaceMessagingService.PlaceMessagingService,
			_sessionClosedNotifications: { [string]: Promise.Promise<()> },
		},
		{} :: typeof({ __index = DataStoreMessageHelper })
	))
	& BaseObject.BaseObject

export type CloseSessionRequest = {
	type: "close-session",
	requesterSessionId: string,
}
export type CloseSessionComplete = {
	type: "close-session-complete",
	senderId: string,
}

export type DataStoreMessage = CloseSessionRequest | CloseSessionComplete

function DataStoreMessageHelper.new(serviceBag: ServiceBag.ServiceBag, dataStore: any): DataStoreMessageHelper
	local self: DataStoreMessageHelper = setmetatable(BaseObject.new() :: any, DataStoreMessageHelper)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._placeMessagingService = self._serviceBag:GetService(PlaceMessagingService :: any)

	self._dataStore = assert(dataStore, "No dataStore")
	self._sessionClosedNotifications = {}

	self._maid:GiveTask(
		self._placeMessagingService
			:ObserveMessages(self:_getActiveStoreTopic(self._dataStore:GetSessionId()))
			:Subscribe(function(data, metadata)
				self:_handleSubscription(data, metadata)
			end)
	)

	return self
end

--[=[
	Returns the service bag used by this helper. (Used for comparison)

	@return ServiceBag
]=]
function DataStoreMessageHelper.GetServiceBag(self: DataStoreMessageHelper): ServiceBag.ServiceBag
	return self._serviceBag
end

--[=[
	Promises a graceful close session notification to other sessions.

	@param placeId number
	@param jobId string
	@param sessionId string
	@return Promise<()>
]=]
function DataStoreMessageHelper.PromiseCloseSessionGraceful(
	self: DataStoreMessageHelper,
	placeId: number,
	jobId: string,
	sessionId: string
): Promise.Promise<()>
	local promise: any = self._sessionClosedNotifications[sessionId]
	if not promise then
		promise = Promise.new()
		self._sessionClosedNotifications[sessionId] = promise
	end
	assert(promise, "Typechecking assertion")

	self._maid[promise] = promise
	promise:Finally(function()
		self._maid[promise] = nil
	end)

	PromiseMaidUtils.whilePromise(promise, function(maid)
		maid:GiveTask(task.delay(5, function()
			if promise:IsPending() then
				promise:Reject("Graceful session close timed out after 5 seconds")
			end
		end))
	end)

	return self:PromiseSendSessionMessage(placeId, jobId, sessionId, {
		type = "close-session",
		requesterSessionId = self._dataStore:GetSessionId(),
	}):Then(function()
		return promise
	end)
end

--[=[
	Promises sending a message to another DataStore session.

	@param placeId number
	@param jobId string
	@param sessionId string
	@param message DataStoreMessage
	@return Promise<()>
]=]
function DataStoreMessageHelper.PromiseSendSessionMessage(
	self: DataStoreMessageHelper,
	placeId: number,
	jobId: string,
	sessionId: string,
	message: DataStoreMessage
): Promise.Promise<()>
	assert(self._dataStore:GetSessionId() ~= sessionId, "Cannot message self")

	if DEBUG_LOG then
		print("[DataStoreMessageHelper] - Sending message:", MessagingServiceUtils.toHumanReadable(message))
	end

	local topic = self:_getActiveStoreTopic(sessionId)
	return self._maid:GivePromise(self._placeMessagingService:SendMessage(placeId, jobId, topic, message))
end

function DataStoreMessageHelper._handleSubscription(
	self: DataStoreMessageHelper,
	data: any,
	metadata: PlaceMessagingService.PlacePacketMetadata
): ()
	if type(data) ~= "table" or type(data.type) ~= "string" then
		warn(`[DataStoreMessageHelper] - Received malformed message: {MessagingServiceUtils.toHumanReadable(data)}`)
		return
	end

	if DEBUG_LOG then
		print("[DataStoreMessageHelper] - Received message:", MessagingServiceUtils.toHumanReadable(data))
	end

	if data.type == "close-session" then
		local closeSessionPromise = self._dataStore:PromiseCloseSession()

		if type(data.requesterSessionId) == "string" then
			local topic = self:_getActiveStoreTopic(data.requesterSessionId)
			local senderId = self._dataStore:GetSessionId()

			closeSessionPromise:Then(function()
				-- We could have GCed by now, but try to send off a notification to the requester
				self._placeMessagingService:SendMessageToAddress(metadata.from, topic, {
					type = "close-session-complete",
					senderId = senderId,
				})
			end)
		end
	elseif data.type == "close-session-complete" then
		if type(data.senderId) ~= "string" then
			warn(
				`[DataStoreMessageHelper] - Received malformed close-session-complete message: {MessagingServiceUtils.toHumanReadable(
					data
				)}`
			)
			return
		end

		local promise = self._sessionClosedNotifications[data.senderId]
		if promise then
			self._sessionClosedNotifications[data.senderId] = nil
			promise:Resolve()
		else
			warn(
				`[DataStoreMessageHelper] - Received unexpected close-session-complete from {data.senderId} (no pending promise)`
			)
		end
	else
		warn(`[DataStoreMessageHelper] - Received unknown message type: {MessagingServiceUtils.toHumanReadable(data)}`)
	end
end

function DataStoreMessageHelper._getActiveStoreTopic(self: DataStoreMessageHelper, sessionId: string): string
	return `DataStore_{self._dataStore:GetKey()}_{sessionId}`
end

return DataStoreMessageHelper
