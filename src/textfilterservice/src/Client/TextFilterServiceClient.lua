--[=[
	@class TextFilterServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Promise = require("Promise")
local PromiseGetRemoteFunction = require("PromiseGetRemoteFunction")
local TextFilterServiceConstants = require("TextFilterServiceConstants")
local Rx = require("Rx")
local TextFilterUtils = require("TextFilterUtils")

local TextFilterServiceClient = {}
TextFilterServiceClient.ServiceName = "TextFilterServiceClient"

--[=[
	Filters a non-chat string for a user

	@param text string
	@param fromUserId number
	@return Promise<string>
]=]
function TextFilterServiceClient:PromiseNonChatStringForUser(text, fromUserId)
	assert(type(text) == "string", "Bad text")
	assert(type(fromUserId) == "number", "Bad fromUserId")

	return self:_promiseInvokeRemoteFunction(
		TextFilterServiceConstants.REQUEST_NON_CHAT_STRING_FOR_USER,
		text,
		fromUserId)
end

--[=[
	Filters a non-chat string for a broadcast

	@param text string
	@param fromUserId number
	@return Promise<string>
]=]
function TextFilterServiceClient:PromiseNonChatStringForBroadcast(text, fromUserId)
	assert(type(text) == "string", "Bad text")
	assert(type(fromUserId) == "number", "Bad fromUserId")

	return self:_promiseInvokeRemoteFunction(
		TextFilterServiceConstants.REQUEST_NON_CHAT_STRING_FOR_BROADCAST,
		text,
		fromUserId)
end

--[=[
	Filters a preview-non-chat string for a broadcast

	@param text string
	@return Promise<string>
]=]
function TextFilterServiceClient:PromisePreviewNonChatStringForBroadcast(text: string)
	assert(type(text) == "string", "Bad text")

	return self:_promiseInvokeRemoteFunction(
		TextFilterServiceConstants.REQUEST_PREVIEW_NON_CHAT_STRING_FOR_BROADCAST,
		text)
end

--[=[
	Observes a non-chat string preview for broadcast

	@param text string
	@return Promise<string>
]=]
function TextFilterServiceClient:ObservePreviewNonChatStringForBroadcast(text)
	return Rx.fromPromise(self:PromisePreviewNonChatStringForBroadcast(text))
end

function TextFilterServiceClient:_promiseInvokeRemoteFunction(request, text, ...)
	assert(type(request) == "string", "Bad request")
	assert(type(text) == "string", "Bad text")

	local args = table.pack(...)

	if not RunService:IsRunning() then
		return self:_fakeTestFilter(text)
	end

	return self:_promiseRemoteFunction()
		:Then(function(remoteFunction)
			return Promise.spawn(function(resolve, reject)
				local resultOk, result
				local ok, err = pcall(function()
					resultOk, result = remoteFunction:InvokeServer(request, text, table.unpack(args, 1, args.n))
				end)

				if not ok then
					return reject(err)
				end

				if not resultOk then
					return reject(result or "Failed to get a valid result from server")
				end

				if type(result) ~= "string" then
					return reject(err or result or "Failed to get string result from server")
				end

				return resolve(TextFilterUtils.addBackInNewLinesAndWhitespace(text, result))
			end)
		end)
end

function TextFilterServiceClient:_promiseRemoteFunction()
	if self._remoteFunctionPromise then
		return self._remoteFunctionPromise
	end

	self._remoteFunctionPromise = PromiseGetRemoteFunction(TextFilterServiceConstants.REMOTE_FUNCTION_NAME)
	return self._remoteFunctionPromise
end

function TextFilterServiceClient:_fakeTestFilter(text)
	local filteredText = text
	filteredText = string.gsub(filteredText, "[fF][uU][cC][kK]", "####")
	filteredText = string.gsub(filteredText, "\n", "")

	return Promise.spawn(function(resolve, _)
		-- Simulate testing
		task.delay(0.5, function()
			resolve(TextFilterUtils.addBackInNewLinesAndWhitespace(text, filteredText))
		end)
	end)
end

return TextFilterServiceClient