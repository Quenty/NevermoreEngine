--!strict
--[=[
	@class MessagingServiceUtils
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")

local Promise = require("Promise")

local DEBUG_PUBLISH = false
local DEBUG_SUBSCRIBE = false

local MessagingServiceUtils = {}

--[=[
	Wraps MessagingService:PublishAsync(topic, message)
	@param topic string
	@param message any
	@param messagingService any? -- Injection seam; defaults to the real MessagingService
	@return Promise
]=]
function MessagingServiceUtils.promisePublish(topic: string, message: any?, messagingService: any?): Promise.Promise<()>
	assert(type(topic) == "string", "Bad topic")

	local robloxMessagingService = messagingService or MessagingService

	return Promise.spawn(function(resolve, reject)
		if DEBUG_PUBLISH then
			print(string.format("Publishing on %q: ", topic), MessagingServiceUtils.toHumanReadable(message))
		end

		local ok, err = pcall(function()
			robloxMessagingService:PublishAsync(topic, message)
		end)
		if not ok then
			if DEBUG_PUBLISH then
				warn(string.format("Failed to publish on %q due to %q", topic, err or "nil"))
			end
			return reject(err)
		end
		return resolve()
	end)
end

export type SubscriptionData = {
	Data: any,
	Sent: number,
}

--[=[
	Wraps MessagingService:SubscribeAsync(topic, callback)
	@param topic string
	@param callback callback
	@param messagingService any? -- Injection seam; defaults to the real MessagingService
	@return Promise<RBXScriptConnection>
]=]
function MessagingServiceUtils.promiseSubscribe(
	topic: string,
	callback: (SubscriptionData) -> (),
	messagingService: any?
): Promise.Promise<RBXScriptConnection>
	assert(type(topic) == "string", "Bad topic")
	assert(type(callback) == "function", "Bad callback")

	local robloxMessagingService = messagingService or MessagingService

	if DEBUG_SUBSCRIBE then
		print(string.format("Listening on %q", topic))

		local oldCallback = callback
		callback = function(message: SubscriptionData)
			print(string.format("Recieved on %q", topic), MessagingServiceUtils.toHumanReadable(message))
			oldCallback(message)
		end
	end

	return Promise.spawn(function(resolve, reject)
		local connection
		local ok, err = pcall(function()
			connection = robloxMessagingService:SubscribeAsync(topic, callback)
		end)
		if not ok then
			if DEBUG_PUBLISH then
				warn(string.format("Failed to subscribe on %q due to %q", topic, err or "nil"))
			end
			return reject(err)
		end

		return resolve(connection)
	end)
end

function MessagingServiceUtils.toHumanReadable(message: any)
	if type(message) ~= "table" then
		return tostring(message)
	end

	return HttpService:JSONEncode(message)
end

return MessagingServiceUtils
