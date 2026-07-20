--!strict
--[=[
	In-memory stand-in for a Roblox `GlobalDataStore` used by tests. It faithfully
	round-trips values through a deep copy (mimicking JSON serialization, so aliasing
	bugs surface the same way they would against a real datastore) and lets tests inject
	failures such as the `509` Personal-RCC block.

	It is a first-class citizen of the datastore package: the `DataStorePromises` wrappers
	accept it anywhere a real datastore `Instance` is expected via
	[DataStoreMock.isDataStoreMock].

	```lua
	local store = DataStoreMock.new("PlayerData", "SaveData")
	store:SetRaw("key", { coins = 5 })

	-- Simulate Roblox datastores being down
	store:FailAllRequests(DataStoreMock.OPERATION_NOT_ALLOWED_509)
	```

	@server
	@class DataStoreMock
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local Table = require("Table")

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end

	return Table.deepCopy(value)
end

-- Mirrors how Roblox reports a value that serializes past the per-key size ceiling.
local function valueTooLargeMessage(maxValueLength: number): string
	return string.format(
		"105: The value provided exceeds the %d byte maximum size limit for a data store value",
		maxValueLength
	)
end

local DataStoreMock = {}
DataStoreMock.ClassName = "DataStoreMock"
DataStoreMock.__index = DataStoreMock

--[=[
	The error Roblox raises when datastore operations run on a Personal RCC. This is the
	real-world failure that motivated the mock.
	@prop OPERATION_NOT_ALLOWED_509 string
	@within DataStoreMock
]=]
DataStoreMock.OPERATION_NOT_ALLOWED_509 =
	"509: Data Store operations blocked while running on a Personal RCC to prevent possible data corruption"

--[=[
	The per-key serialized-value ceiling Roblox enforces (4 MB). Real datastores serialize a key's
	whole value to JSON and reject the write when that blob is larger than this, which is how a save
	fails once too much data accumulates under one key. Pass this (or a smaller value, to trigger it
	without a multi-megabyte payload) to [DataStoreMock.SetMaxValueLength].

	@prop MAX_VALUE_LENGTH number
	@within DataStoreMock
]=]
DataStoreMock.MAX_VALUE_LENGTH = 4194304

export type ErrorInjectorContext = {
	method: string,
	key: string,
	callIndex: number,
	mock: DataStoreMock,
}

export type ErrorInjector = (ErrorInjectorContext) -> string?

export type DataStoreMock = typeof(setmetatable(
	{} :: {
		_name: string,
		_scope: string,
		_store: { [string]: any },
		_userIds: { [string]: { number }? },
		_metadata: { [string]: { [string]: any } },
		_versions: { [string]: number },
		_callCounts: { [string]: number },
		_totalCalls: number,
		_yieldTime: number,
		_errorInjector: ErrorInjector?,
		_blocked: boolean,
		_maxValueLength: number?,
	},
	{} :: typeof({ __index = DataStoreMock })
))

--[=[
	Returns whether the given value is a [DataStoreMock]. Used by [DataStorePromises] so the
	mock can stand in for a real datastore `Instance`.

	@param value any
	@return boolean
]=]
function DataStoreMock.isDataStoreMock(value: any): boolean
	return type(value) == "table" and getmetatable(value) == DataStoreMock
end

--[=[
	Constructs a new DataStoreMock.

	@param name string?
	@param scope string?
	@return DataStoreMock
]=]
function DataStoreMock.new(name: string?, scope: string?): DataStoreMock
	local self = setmetatable({}, DataStoreMock)

	self._name = name or "MockDataStore"
	self._scope = scope or "global"

	self._store = {}
	self._userIds = {}
	self._metadata = {}
	self._versions = {}

	self._callCounts = {}
	self._totalCalls = 0
	self._yieldTime = 0
	self._errorInjector = nil
	self._blocked = false
	self._maxValueLength = nil

	return self
end

--[=[
	Sets how long (in seconds) each request yields before completing, to mimic real
	datastore latency. Defaults to 0 (no yield) so tests stay fast.

	@param yieldTime number
]=]
function DataStoreMock.SetYieldTime(self: DataStoreMock, yieldTime: number): ()
	assert(type(yieldTime) == "number" and yieldTime >= 0, "Bad yieldTime")

	self._yieldTime = yieldTime
end

--[=[
	Enforces a serialized-value ceiling on `SetAsync`/`UpdateAsync`, mirroring the way real
	datastores reject a write once a key's whole value serializes past their per-key size limit.
	A write whose value JSON-encodes to more than `maxValueLength` bytes throws (and stores nothing),
	so tests can exercise the overflow-save failure path without a multi-megabyte payload. A value the
	mock cannot serialize at all throws the same way a real datastore rejects non-UTF-8 data.

	Pass [DataStoreMock.MAX_VALUE_LENGTH] for the real 4 MB ceiling, a smaller number to trigger it
	cheaply, or nil to disable the check (the default, so existing tests are unaffected).

	@param maxValueLength number?
]=]
function DataStoreMock.SetMaxValueLength(self: DataStoreMock, maxValueLength: number?): ()
	assert(maxValueLength == nil or (type(maxValueLength) == "number" and maxValueLength >= 0), "Bad maxValueLength")

	self._maxValueLength = maxValueLength
end

--[=[
	Injects a callback consulted before every request. Returning a string from the callback
	makes that request throw the string as its error; returning nil lets the request proceed.

	@param errorInjector ((ErrorInjectorContext) -> string?)?
]=]
function DataStoreMock.SetErrorInjector(self: DataStoreMock, errorInjector: ErrorInjector?): ()
	assert(type(errorInjector) == "function" or errorInjector == nil, "Bad errorInjector")

	self._errorInjector = errorInjector
end

--[=[
	Makes every subsequent request throw the given error until [DataStoreMock.StopFailing]
	is called. Simulates a total datastore outage.

	@param errorMessage string? -- Defaults to the 509 Personal-RCC error
]=]
function DataStoreMock.FailAllRequests(self: DataStoreMock, errorMessage: string?): ()
	local message = errorMessage or DataStoreMock.OPERATION_NOT_ALLOWED_509
	assert(type(message) == "string", "Bad errorMessage")

	self:SetErrorInjector(function()
		return message
	end)
end

--[=[
	Makes the next `count` requests throw the given error, then recover. Simulates a
	transient outage that the retry logic is expected to survive.

	@param count number
	@param errorMessage string? -- Defaults to the 509 Personal-RCC error
]=]
function DataStoreMock.FailNextRequests(self: DataStoreMock, count: number, errorMessage: string?): ()
	assert(type(count) == "number" and count >= 0, "Bad count")
	local message = errorMessage or DataStoreMock.OPERATION_NOT_ALLOWED_509
	assert(type(message) == "string", "Bad errorMessage")

	local remaining = count
	self:SetErrorInjector(function()
		if remaining > 0 then
			remaining -= 1
			return message
		end
		return nil
	end)
end

--[=[
	Clears any injected failures.
]=]
function DataStoreMock.StopFailing(self: DataStoreMock): ()
	self._errorInjector = nil
end

--[=[
	Makes every subsequent request hang (yield) inside the datastore call until
	[DataStoreMock.UnblockRequests] is called. Simulates a request that does not settle -- e.g. a
	lock command that can take up to ~30s to propagate across servers -- so tests can exercise a
	request in flight (and its maid cancelling the yielding thread).
]=]
function DataStoreMock.BlockRequests(self: DataStoreMock): ()
	self._blocked = true
end

--[=[
	Releases requests blocked by [DataStoreMock.BlockRequests]. A request whose thread was cancelled
	while blocked never resumes.
]=]
function DataStoreMock.UnblockRequests(self: DataStoreMock): ()
	self._blocked = false
end

--[=[
	Returns the number of times a given API was called (or total across all APIs when no
	method is given). Failed calls count too.

	@param method string? -- e.g. "GetAsync", "UpdateAsync"
	@return number
]=]
function DataStoreMock.GetCallCount(self: DataStoreMock, method: string?): number
	if method == nil then
		return self._totalCalls
	end
	return self._callCounts[method] or 0
end

--[=[
	Directly seeds a stored value without datastore semantics (no version bump, no failure
	injection). For test setup.

	@param key string
	@param value any
]=]
function DataStoreMock.SetRaw(self: DataStoreMock, key: string, value: any): ()
	assert(type(key) == "string", "Bad key")

	self._store[key] = deepCopy(value)
end

--[=[
	Directly reads a stored value without datastore semantics. For test assertions.

	@param key string
	@return any
]=]
function DataStoreMock.GetRaw(self: DataStoreMock, key: string): any
	assert(type(key) == "string", "Bad key")

	return deepCopy(self._store[key])
end

function DataStoreMock._beginRequest(self: DataStoreMock, method: string, key: string): ()
	self._callCounts[method] = (self._callCounts[method] or 0) + 1
	self._totalCalls += 1

	if self._yieldTime > 0 then
		task.wait(self._yieldTime)
	end

	-- Hang here until unblocked (or until the calling thread is cancelled by its maid).
	while self._blocked do
		task.wait()
	end

	if self._errorInjector then
		local errorMessage = self._errorInjector({
			method = method,
			key = key,
			callIndex = self._totalCalls,
			mock = self,
		})
		if errorMessage then
			error(errorMessage, 0)
		end
	end
end

-- Rejects a write whose value serializes past the configured size ceiling, the way real datastores
-- reject a key value that grew too large to store safely. A no-op unless SetMaxValueLength was set.
function DataStoreMock._assertWithinSizeLimit(self: DataStoreMock, value: any): ()
	local maxValueLength = self._maxValueLength
	if maxValueLength == nil or value == nil then
		return
	end

	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(value)
	end)
	if not ok then
		-- A real datastore likewise refuses a value it cannot serialize.
		error("104: Cannot store value in data store. Data stores can only accept valid UTF-8 characters", 0)
	end

	if #encoded > maxValueLength then
		error(valueTooLargeMessage(maxValueLength), 0)
	end
end

function DataStoreMock._makeKeyInfo(self: DataStoreMock, key: string)
	local userIds = self._userIds[key]
	local metadata = self._metadata[key]
	local version = self._versions[key] or 0

	return {
		Version = tostring(version),
		CreatedTime = 0,
		UpdatedTime = 0,
		GetUserIds = function()
			return Table.deepCopy(userIds or {})
		end,
		GetMetadata = function()
			return Table.deepCopy(metadata or {})
		end,
	}
end

--[=[
	Mimics `GlobalDataStore:GetAsync`.

	@param key string
	@return (any, any) -- value, keyInfo
]=]
function DataStoreMock.GetAsync(self: DataStoreMock, key: string): (any, any)
	assert(type(key) == "string", "Bad key")

	self:_beginRequest("GetAsync", key)

	return deepCopy(self._store[key]), self:_makeKeyInfo(key)
end

--[=[
	Mimics `GlobalDataStore:SetAsync`.

	@param key string
	@param value any
	@param userIds { number }?
	@param options any?
	@return string -- version
]=]
function DataStoreMock.SetAsync(
	self: DataStoreMock,
	key: string,
	value: any,
	userIds: { number }?,
	options: any?
): string
	assert(type(key) == "string", "Bad key")

	self:_beginRequest("SetAsync", key)
	self:_assertWithinSizeLimit(value)

	self._store[key] = deepCopy(value)
	self._userIds[key] = userIds and Table.deepCopy(userIds) or nil
	if options and options.GetMetadata then
		self._metadata[key] = options:GetMetadata()
	end
	self._versions[key] = (self._versions[key] or 0) + 1

	return tostring(self._versions[key])
end

--[=[
	Mimics `GlobalDataStore:UpdateAsync`. The transform receives the current value and a
	key-info stand-in, and returns `newValue [, userIds [, metadata]]`. Returning nil cancels
	the update (matching Roblox semantics).

	@param key string
	@param transformFunction (any, any) -> ...any
	@return (any, any) -- value, keyInfo
]=]
function DataStoreMock.UpdateAsync(
	self: DataStoreMock,
	key: string,
	transformFunction: (any, any) -> ...any
): (any, any)
	assert(type(key) == "string", "Bad key")
	assert(type(transformFunction) == "function", "Bad transformFunction")

	self:_beginRequest("UpdateAsync", key)

	local current = deepCopy(self._store[key])
	local keyInfo = self:_makeKeyInfo(key)

	local newValue, userIds, metadata = transformFunction(current, keyInfo)
	if newValue == nil then
		-- Update cancelled; nothing written
		return nil, keyInfo
	end

	self:_assertWithinSizeLimit(newValue)

	self._store[key] = deepCopy(newValue)
	self._userIds[key] = userIds and Table.deepCopy(userIds) or nil
	self._metadata[key] = metadata and Table.deepCopy(metadata) or nil
	self._versions[key] = (self._versions[key] or 0) + 1

	return deepCopy(self._store[key]), self:_makeKeyInfo(key)
end

--[=[
	Mimics `GlobalDataStore:RemoveAsync`.

	@param key string
	@return (any, any) -- removed value, keyInfo
]=]
function DataStoreMock.RemoveAsync(self: DataStoreMock, key: string): (any, any)
	assert(type(key) == "string", "Bad key")

	self:_beginRequest("RemoveAsync", key)

	local removed = deepCopy(self._store[key])
	local keyInfo = self:_makeKeyInfo(key)

	self._store[key] = nil
	self._userIds[key] = nil
	self._metadata[key] = nil

	return removed, keyInfo
end

--[=[
	Mimics `GlobalDataStore:IncrementAsync`.

	@param key string
	@param delta number?
	@return number
]=]
function DataStoreMock.IncrementAsync(self: DataStoreMock, key: string, delta: number?): number
	assert(type(key) == "string", "Bad key")

	self:_beginRequest("IncrementAsync", key)

	local current = self._store[key]
	assert(current == nil or type(current) == "number", "Cannot increment non-number value")

	local newValue = (current or 0) + (delta or 1)
	self._store[key] = newValue
	self._versions[key] = (self._versions[key] or 0) + 1

	return newValue
end

return DataStoreMock
