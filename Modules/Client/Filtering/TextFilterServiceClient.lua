---
-- @module TextFilterServiceClient
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")

local Promise = require("Promise")
local PromiseGetRemoteFunction = require("PromiseGetRemoteFunction")
local TextFilterServiceConstants = require("TextFilterServiceConstants")

local TextFilterServiceClient = {}

function TextFilterServiceClient:PromisePreviewFilterForBroadcast(text)
	assert(type(text) == "string")

	-- For testing!
	if not RunService:IsRunning() then
		text = text:gsub("[fF][uU][cC][kK]", "####")
		return Promise.spawn(function(resolve, reject)
			-- Simulate testing
			delay(0.5, function()
				resolve(text)
			end)
		end)
	end

	local promise = Promise.new()

	promise:Resolve(self:_promiseRemoteFunction()
		:Then(function(remoteFunction)
			if promise:IsRejected() then
				return Promise.rejected()
			end

			return Promise.spawn(function(resolve, reject)
				local result
				local ok, err = pcall(function()
					result = remoteFunction:InvokeServer(text)
				end)

				if not ok then
					return reject(err)
				end

				if type(result) ~= "string" then
					return reject(err)
				end

				return resolve(result)
			end)
		end))

	return promise
end

function TextFilterServiceClient:_promiseRemoteFunction()
	if self._remoteFunctionPromise then
		return self._remoteFunctionPromise
	end

	self._remoteFunctionPromise = PromiseGetRemoteFunction(TextFilterServiceConstants.REMOTE_FUNCTION_NAME)
	return self._remoteFunctionPromise
end

return TextFilterServiceClient