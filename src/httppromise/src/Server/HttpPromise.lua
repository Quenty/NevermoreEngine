--!strict
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

export type HTTPRequest = {
	Url: string,
	Method: "POST" | "GET" | "PUT" | "DELETE",
	Headers: { [string]: string }?,
	Body: string?,
	Compress: Enum.HttpCompression?,
}

export type HTTPResponse = {
	Success: boolean,
	StatusCode: number,
	StatusMessage: string,
	Headers: { [string]: string },
	Body: string,
}

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

	@param request HTTPRequest
	@return Promise<table>
]=]
function HttpPromise.request(request: HTTPRequest): Promise.Promise<()>
	if DEBUG_REQUEST then
		print("Sending request", HttpService:JSONEncode(request))
	end

	return Promise.spawn(function(resolve, reject)
		local response
		local ok, err = pcall(function()
			response = HttpService:RequestAsync(request)
		end)

		if DEBUG_RESPONSE then
			print(string.format("Response: %d %s %s", response.StatusCode, request.Method, request.Url), response.Body)
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
	Returns true if the value is an HttpResponse

	@param value any
	@return boolean
]=]
function HttpPromise.isHttpResponse(value: any): boolean
	return type(value) == "table"
		and type(value.Success) == "boolean"
		and type(value.StatusCode) == "number"
		and type(value.StatusMessage) == "string"
		and type(value.Headers) == "table"
		and type(value.Body) == "string"
end

--[=[
	Converts an http response to a string for debugging

	@param value HttpResponse
	@return string
]=]
function HttpPromise.convertHttpResponseToString(value: HTTPResponse): string
	assert(HttpPromise.isHttpResponse(value), "Bad value")

	return string.format("%d: %s - %s", value.StatusCode, value.StatusMessage, value.Body)
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
function HttpPromise.json(request: HTTPRequest | string): Promise.Promise<any>
	local finalRequest: HTTPRequest
	if type(request) == "string" then
		finalRequest = {
			Method = "GET",
			Url = request,
		}
	else
		finalRequest = request
	end

	return HttpPromise.request(finalRequest):Then(HttpPromise.decodeJson)
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
	for _, item in { ... } do
		if type(item) == "string" then
			warn(item)
		elseif type(item) == "table" and type(item.StatusCode) == "number" then
			warn(string.format("Failed request %d %q", item.StatusCode, tostring(item.Body)))
		end
	end
end

--[=[
	Decodes JSON from the response

	@param response { Body: string }
	@return table
]=]
function HttpPromise.decodeJson(response: HTTPResponse)
	assert(response, "Bad response")

	if type(response.Body) ~= "string" then
		return Promise.rejected(string.format("Body is not of type string, but says %q", tostring(response.Body)))
	end

	return Promise.new(function(resolve, reject)
		local decoded
		local ok, err = pcall(function()
			decoded = HttpService:JSONDecode(response.Body)
		end)

		if not ok then
			reject(err)
			return
		elseif decoded ~= nil then
			resolve(decoded)
			return
		else
			reject("Decoded nothing")
			return
		end
	end)
end

return HttpPromise