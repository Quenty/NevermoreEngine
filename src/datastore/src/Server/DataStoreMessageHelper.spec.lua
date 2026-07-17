--!nonstrict
--[[
	Coverage for DataStoreMessageHelper, the coordinator that drives graceful cross-server
	session-close over MessagingService. The full request/complete handshake needs a second server
	to answer, so cross-server behaviour is characterized rather than asserted; what a single server
	can verify (construction, the "cannot message self" guard, messaging wiring, and the
	MessagingServiceUtils.toHumanReadable formatter) is exercised here.

	@class DataStoreMessageHelper.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStoreMessageHelper = require("DataStoreMessageHelper")
local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local MessagingServiceUtils = require("MessagingServiceUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Builds a real ServiceBag, a DataStore over a fresh mock, and a helper wired to both.
-- Returns all of them plus a cleanup so each test tears its own world down.
local function newHelper()
	local serviceBag = ServiceBag.new()
	-- The helper pulls PlaceMessagingService off the bag; register it before Start.
	serviceBag:GetService(require("PlaceMessagingService"))
	serviceBag:Init()
	serviceBag:Start()

	local mock = DataStoreMock.new()
	local dataStore = DataStore.new(mock, "player_1")

	-- The helper only reads GetSessionId()/GetKey() off the store, both of which a plain
	-- DataStore provides (the session id is a GUID assigned in DataStore.new).
	local helper = DataStoreMessageHelper.new(serviceBag, dataStore)

	local function cleanup()
		helper:Destroy()
		dataStore:Destroy()
		serviceBag:Destroy()
	end

	return helper, dataStore, cleanup
end

describe("DataStoreMessageHelper.new", function()
	it("should construct against a real ServiceBag and DataStore", function()
		local helper, _, cleanup = newHelper()

		expect(helper).never.toBeNil()

		cleanup()
	end)

	it("should expose the ServiceBag it was built with", function()
		local serviceBag = ServiceBag.new()
		serviceBag:GetService(require("PlaceMessagingService"))
		serviceBag:Init()
		serviceBag:Start()

		local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
		local helper = DataStoreMessageHelper.new(serviceBag, dataStore)

		expect((helper:GetServiceBag() == serviceBag)).toEqual(true)

		helper:Destroy()
		dataStore:Destroy()
		serviceBag:Destroy()
	end)

	it("should reject a nil serviceBag", function()
		local dataStore = DataStore.new(DataStoreMock.new(), "player_1")

		expect(function()
			DataStoreMessageHelper.new(nil, dataStore)
		end).toThrow("No serviceBag")

		dataStore:Destroy()
	end)

	it("should not error on construct then Destroy", function()
		-- Build directly so we control teardown and never double-Destroy the helper.
		local serviceBag = ServiceBag.new()
		serviceBag:GetService(require("PlaceMessagingService"))
		serviceBag:Init()
		serviceBag:Start()

		local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
		local helper = DataStoreMessageHelper.new(serviceBag, dataStore)

		expect(function()
			helper:Destroy()
		end).never.toThrow()

		dataStore:Destroy()
		serviceBag:Destroy()
	end)
end)

describe("DataStoreMessageHelper.PromiseSendSessionMessage", function()
	it("should refuse to message its own session synchronously", function()
		local helper, dataStore, cleanup = newHelper()

		local ownSessionId = dataStore:GetSessionId()
		expect(function()
			helper:PromiseSendSessionMessage(1, "job", ownSessionId, {
				type = "close-session",
				requesterSessionId = ownSessionId,
			})
		end).toThrow("Cannot message self")

		cleanup()
	end)
end)

describe("DataStoreMessageHelper.PromiseCloseSessionGraceful", function()
	it("should return a promise (cross-server outcome is not unit-testable single-server)", function()
		-- The graceful handshake needs a second server to answer, so we only assert it returns a
		-- promise; its settlement is environment dependent and covered by real multi-server usage.
		local helper, _, cleanup = newHelper()

		local promise = helper:PromiseCloseSessionGraceful(1, "some-other-job", "some-other-session")
		expect(promise).never.toBeNil()

		cleanup()
	end)
end)

describe("DataStore.SetSessionMessagingEnabled wiring", function()
	it("should enable then disable session messaging without erroring", function()
		local serviceBag = ServiceBag.new()
		serviceBag:GetService(require("PlaceMessagingService"))
		serviceBag:Init()
		serviceBag:Start()

		local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
		-- Messaging is documented to work alongside session locking; enable both like real usage.
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		expect(function()
			dataStore:SetSessionMessagingEnabled(true, serviceBag)
		end).never.toThrow()

		expect(function()
			dataStore:SetSessionMessagingEnabled(false)
		end).never.toThrow()

		dataStore:Destroy()
		serviceBag:Destroy()
	end)
end)

describe("MessagingServiceUtils.toHumanReadable", function()
	it("should JSON-encode a table message", function()
		local result = MessagingServiceUtils.toHumanReadable({
			type = "close-session",
			requesterSessionId = "abc",
		})

		expect((type(result))).toEqual("string")
		-- JSON key order is not guaranteed, so pin the shape, not the exact string.
		expect((string.sub(result, 1, 1))).toEqual("{")
	end)

	it("should stringify a non-table message", function()
		expect((MessagingServiceUtils.toHumanReadable(5))).toEqual("5")
		expect((MessagingServiceUtils.toHumanReadable("hi"))).toEqual("hi")
		expect((MessagingServiceUtils.toHumanReadable(true))).toEqual("true")
		expect((MessagingServiceUtils.toHumanReadable(nil))).toEqual("nil")
	end)
end)
