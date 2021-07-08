--- Provides a wrapper around HttpService with a promise API
-- @module HttpPromise

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local HttpService = game:GetService("HttpService")

local Promise = require("Promise")

local DEBUG_REQUEST = false
local DEBUG_RESPONSE = false

local HttpPromise = {}

function HttpPromise.request(request)
	if DEBUG_REQUEST then
		print("Sending request", HttpService:JSONEncode(request))
	end

	return Promise.defer(function(resolve, reject)
		local response
		local ok, err = pcall(function()
			response = HttpService:RequestAsync(request)
		end)

		if DEBUG_RESPONSE then
			print(("Response: %d %s %s"):format(response.StatusCode, request.Method, request.Url), response.Body)
		end

		if not ok then
			reject(err)
			return
		end

		if not response.Success then
			reject(response)
			return
		end

		resolve(response)
		return
	end)
end

function HttpPromise.json(request)
	if type(request) == "string" then
		request = {
			Method = "GET";
			Url = request;
		}
	end

	return HttpPromise.request(request)
		:Then(HttpPromise.decodeJson)
end

function HttpPromise.logFailedRequests(...)
	for _, item in pairs({...}) do
		if type(item) == "string" then
			warn(item)
		elseif type(item) == "table" and type(item.StatusCode) == "number" then
			warn(("Failed request %d %q"):format(item.StatusCode, tostring(item.Body)))
		end
	end
end

function HttpPromise.decodeJson(response)
	assert(response)
	if type(response.Body) ~= "string" then
		return Promise.rejected(("Body is not of type string, but says %q"):format(tostring(response.Body)))
	end

	return Promise.new(function(resolve, reject)
		local decoded
		local ok, err = pcall(function()
			decoded = HttpService:JSONDecode(response.Body)
		end)

		if not ok then
			reject(err)
			return
		elseif decoded then
			resolve(decoded)
			return
		else
			reject("decoded nothing")
			return
		end
	end)
end

return HttpPromise
