--!strict
--[=[
	In-memory stand-in for [HttpPromise.request] used to test InfluxDB writes without making real HTTP
	calls. Inject its [InfluxDBRequestHandlerMock.Handler] wherever an [InfluxDBRequestHandler] is
	expected -- into [InfluxDBClient.new], via [InfluxDBService.SetRequestHandler], or use
	[InfluxDBClient.newMock], which wires one up for you.

	Every request handed to the mock is recorded for inspection. By default each request resolves with a
	204 success response; call [InfluxDBRequestHandlerMock.SetResponder] to control the response (for
	example to simulate a failure).

	```lua
	local requestMock = InfluxDBRequestHandlerMock.new()
	local client = InfluxDBClient.new(config, requestMock.Handler)
	-- ...write some points...
	print(#requestMock:GetRequests())
	```

	@server
	@class InfluxDBRequestHandlerMock
]=]

local require = require(script.Parent.loader).load(script)

local HttpPromise = require("HttpPromise")
local Promise = require("Promise")

local InfluxDBRequestHandlerMock = {}
InfluxDBRequestHandlerMock.ClassName = "InfluxDBRequestHandlerMock"
InfluxDBRequestHandlerMock.__index = InfluxDBRequestHandlerMock

--[=[
	A responder controls how the mock answers a request, so a test can resolve or reject however it needs.

	@type Responder (request: HttpPromise.HTTPRequest) -> Promise<HttpPromise.HTTPResponse>
	@within InfluxDBRequestHandlerMock
]=]
export type Responder = (request: HttpPromise.HTTPRequest) -> Promise.Promise<HttpPromise.HTTPResponse>

export type InfluxDBRequestHandlerMock = typeof(setmetatable(
	{} :: {
		-- The request handler function to inject; recording is done through it.
		Handler: Responder,
		_requests: { HttpPromise.HTTPRequest },
		_responder: Responder?,
	},
	{} :: typeof({ __index = InfluxDBRequestHandlerMock })
))

local function defaultResponse(): HttpPromise.HTTPResponse
	return {
		Success = true,
		StatusCode = 204,
		StatusMessage = "No Content",
		Headers = {},
		Body = "",
	}
end

--[=[
	Returns whether the given value is an [InfluxDBRequestHandlerMock].

	@param value any
	@return boolean
]=]
function InfluxDBRequestHandlerMock.isInfluxDBRequestHandlerMock(value: any): boolean
	return type(value) == "table" and getmetatable(value) == InfluxDBRequestHandlerMock
end

--[=[
	Constructs a new InfluxDBRequestHandlerMock.

	@return InfluxDBRequestHandlerMock
]=]
function InfluxDBRequestHandlerMock.new(): InfluxDBRequestHandlerMock
	local self: InfluxDBRequestHandlerMock = setmetatable({} :: any, InfluxDBRequestHandlerMock)

	self._requests = {}
	self._responder = nil

	-- Bound closure so it can be passed wherever a plain [InfluxDBRequestHandler] function is expected.
	self.Handler = function(request)
		return self:_handleRequest(request)
	end

	return self
end

function InfluxDBRequestHandlerMock._handleRequest(
	self: InfluxDBRequestHandlerMock,
	request: HttpPromise.HTTPRequest
): Promise.Promise<HttpPromise.HTTPResponse>
	table.insert(self._requests, request)

	if self._responder then
		return self._responder(request)
	end

	return Promise.resolved(defaultResponse())
end

--[=[
	Sets a responder invoked for each subsequent request, letting a test resolve or reject however it
	needs. Pass nil to restore the default 204 success response.

	@param responder Responder?
]=]
function InfluxDBRequestHandlerMock.SetResponder(self: InfluxDBRequestHandlerMock, responder: Responder?): ()
	assert(type(responder) == "function" or responder == nil, "Bad responder")

	self._responder = responder
end

--[=[
	Returns every request handed to the mock, in order.

	@return { HttpPromise.HTTPRequest }
]=]
function InfluxDBRequestHandlerMock.GetRequests(self: InfluxDBRequestHandlerMock): { HttpPromise.HTTPRequest }
	return self._requests
end

--[=[
	Returns the most recent request handed to the mock, or nil if there have been none.

	@return HttpPromise.HTTPRequest?
]=]
function InfluxDBRequestHandlerMock.GetLastRequest(self: InfluxDBRequestHandlerMock): HttpPromise.HTTPRequest?
	return self._requests[#self._requests]
end

return InfluxDBRequestHandlerMock
