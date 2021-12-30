--[=[
	Provides a wrapper around HttpService with a promise API

	By combining functions in HttpPromise, we can get a generic request result in a very clean way.
	```lua
	local function logToDiscord(body)
		return HttpPromise.request({
			Headers = {
				["Content-Type"] = "application/json";
			};
			Url = DISCORD_LOG_URL;
			Body = HttpService:JSONEncode(data);
			Method = "POST";
		})
		:Then(HttpPromise.decodeJson)
		:Catch(HttpPromise.logFailedRequests)
	end
	```

	@server
	@class HttpPromise
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local Promise = require("Promise")

local DEBUG_REQUEST = false
local DEBUG_RESPONSE = false

local HttpPromise = {}

--[=[
	Decodes JSON from the response

	```lua
	local requestPromise = HttpPromise.request({
		Headers = {
			["Content-Type"] = "application/json";
		};
		Url = DISCORD_LOG_URL;
		Body = HttpService:JSONEncode(data);
		Method = "POST";
	})
	```

	@param request table
	@return Promise<table>
]=]
function HttpPromise.request(request)
	if DEBUG_REQUEST then
		print("Sending request", HttpService:JSONEncode(request))
	end

	return Promise.spawn(function(resolve, reject)
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

--[=[
	Makes a GET JSON request and then expects JSON as a result from said request

	```lua
	HttpPromise.json("https://quenty.org/banned/4397833/status")
		:Then(print)
	```

	@param request table | string
	@return Promise<table>
]=]
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

--[=[
	Logs failed requests and any errors retrieved

	```lua
	HttpPromise.json("https://quenty.org/banned/4397833/status")
		:Catch(HttpPromise.logFailedRequests)
	```

	@param ... any -- A list of requests to retrieve. Meant to be used
]=]
function HttpPromise.logFailedRequests(...)
	for _, item in pairs({...}) do
		if type(item) == "string" then
			warn(item)
		elseif type(item) == "table" and type(item.StatusCode) == "number" then
			warn(("Failed request %d %q"):format(item.StatusCode, tostring(item.Body)))
		end
	end
end

--[=[
	Decodes JSON from the response

	@param response { Body: string }
	@return table
]=]
function HttpPromise.decodeJson(response)
	assert(response, "Bad response")

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
