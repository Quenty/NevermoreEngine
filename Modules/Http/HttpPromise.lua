---
-- @module HttpPromise

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local HttpService = game:GetService("HttpService")

local Promise = require("Promise")

local HttpPromise = {}

function HttpPromise.Method(MethodName, Url, ...)
	local Args = {...}
	
	return Promise.new(function(Fulfill, Reject)
		local Result
		
		local Success, Error = pcall(function()
			Result = HttpService[MethodName](HttpService, Url, unpack(Args))
		end)
		if not Success then
			warn(("[HttpPromise] - Failed request '%s'"):format(tostring(Url)), Error)
			Reject(Error)
		else
			Fulfill(Result)
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