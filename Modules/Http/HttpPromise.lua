---
-- @module HttpPromise

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local HttpService = game:GetService("HttpService")

local Promise = require("Promise")

local HttpPromise = {}

function HttpPromise.Method(methodName, url, ...)
	assert(type(methodName) == "string")
	assert(type(url) == "string")

	local Args = {...}
	
	return Promise.new(function(fulfill, reject)
		local result
		
		local success, err = pcall(function()
			result = HttpService[methodName](HttpService, url, unpack(Args))
		end)
		if not success then
			warn(("[HttpPromise] - Failed request '%s'"):format(url), err)
			reject(err)
		else
			fulfill(result)
		end
	end)
end

function HttpPromise.Get(...)
	return HttpPromise.Method("GetAsync", ...)
end

function HttpPromise.Post(Url, Data, HttpContentType, ...)
	if type(Data) == "table" and HttpContentType == Enum.HttpContentType.ApplicationJson then
		Data = HttpService:JSONEncode(Data)
	end
	return HttpPromise.Method("PostAsync", Url, Data, HttpContentType, ...)
end

function HttpPromise.Json(...)
	return HttpPromise.Get(...):Then(function(Result)
		
		-- Decode
		return Promise.new(function(Fulfill, Reject)
			local Decoded
			local Success, Error = pcall(function()
				Decoded = HttpService:JSONDecode(Result)
			end)
			
			if not Success then
				Reject(Error)
			elseif Decoded then
				Fulfill(Decoded)
			else
				Reject("Decoded nothing")
			end
		end)
	end)
end


return HttpPromise