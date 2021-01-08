---
-- @module TextFilterServiceClient
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")

local Promise = require("Promise")
local PromiseGetRemoteFunction = require("PromiseGetRemoteFunction")
local TextFilterServiceConstants = require("TextFilterServiceConstants")

local TextFilterServiceClient = {}

function TextFilterServiceClient:PromiseNonChatStringForUser(text, fromUserId)
	assert(type(text) == "string")
	assert(type(fromUserId) == "number")

	return self:_promiseInvokeRemoteFunction(
		TextFilterServiceConstants.REQUEST_NON_CHAT_STRING_FOR_USER,
		text,
		fromUserId)
end

function TextFilterServiceClient:PromiseNonChatStringForBroadcast(text, fromUserId)
	assert(type(text) == "string")
	assert(type(fromUserId) == "number")

	return self:_promiseInvokeRemoteFunction(
		TextFilterServiceConstants.REQUEST_NON_CHAT_STRING_FOR_BROADCAST,
		text,
		fromUserId)
end

function TextFilterServiceClient:PromisePreviewNonChatStringForBroadcast(text)
	assert(type(text) == "string")

	return self:_promiseInvokeRemoteFunction(
		TextFilterServiceConstants.REQUEST_PREVIEW_NON_CHAT_STRING_FOR_BROADCAST,
		text)
end

function TextFilterServiceClient:_promiseInvokeRemoteFunction(request, text, ...)
	assert(type(request) == "string")
	assert(type(text) == "string")

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

				return resolve(result)
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
	text = text:gsub("[fF][uU][cC][kK]", "####")

	return Promise.spawn(function(resolve, reject)
		-- Simulate testing
		delay(0.5, function()
			resolve(text)
		end)
	end)
end

return TextFilterServiceClient