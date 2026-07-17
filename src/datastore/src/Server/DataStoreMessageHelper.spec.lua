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
local Maid = require("Maid")
local MessagingServiceUtils = require("MessagingServiceUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local afterEach = Jest.Globals.afterEach

-- Every object a test creates is tracked here and torn down in afterEach, so nothing (a helper's
-- subscription, a store's auto-save loop) can outlive the test. These specs share one Roblox place
-- across all packages, so a leaked background task throws in a later package's window.
local maid = Maid.new()

afterEach(function()
	maid:DoCleaning()
end)

-- Builds a real ServiceBag, a DataStore over a fresh mock, and a helper wired to both. The helper and
-- store are torn down before the bag they borrow PlaceMessagingService from.
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

	maid:GiveTask(function()
		helper:Destroy()
		dataStore:Destroy()
		serviceBag:Destroy()
	end)

	return helper, dataStore
end

describe("DataStoreMessageHelper.new", function()
	it("should construct against a real ServiceBag and DataStore", function()
		local helper = newHelper()

		expect(helper).never.toBeNil()
	end)

	it("should expose the ServiceBag it was built with", function()
		local serviceBag = ServiceBag.new()
		serviceBag:GetService(require("PlaceMessagingService"))
		serviceBag:Init()
		serviceBag:Start()

		local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
		local helper = DataStoreMessageHelper.new(serviceBag, dataStore)

		maid:GiveTask(function()
			helper:Destroy()
			dataStore:Destroy()
			serviceBag:Destroy()
		end)

		expect((helper:GetServiceBag() == serviceBag)).toEqual(true)
	end)

	it("should reject a nil serviceBag", function()
		local dataStore = maid:Add(DataStore.new(DataStoreMock.new(), "player_1"))

		expect(function()
			DataStoreMessageHelper.new(nil, dataStore)
		end).toThrow("No serviceBag")
	end)

	it("should not error on construct then Destroy", function()
		-- Build directly so we control teardown and never double-Destroy the helper.
		local serviceBag = ServiceBag.new()
		serviceBag:GetService(require("PlaceMessagingService"))
		serviceBag:Init()
		serviceBag:Start()

		local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
		local helper = DataStoreMessageHelper.new(serviceBag, dataStore)

		-- This test destroys the helper itself, so the maid only owns the store and the bag.
		maid:GiveTask(function()
			dataStore:Destroy()
			serviceBag:Destroy()
		end)

		expect(function()
			helper:Destroy()
		end).never.toThrow()
	end)
end)

describe("DataStoreMessageHelper.PromiseSendSessionMessage", function()
	it("should refuse to message its own session synchronously", function()
		local helper, dataStore = newHelper()

		local ownSessionId = dataStore:GetSessionId()
		expect(function()
			helper:PromiseSendSessionMessage(1, "job", ownSessionId, {
				type = "close-session",
				requesterSessionId = ownSessionId,
			})
		end).toThrow("Cannot message self")
	end)
end)

describe("DataStoreMessageHelper.PromiseCloseSessionGraceful", function()
	it("should return a promise (cross-server outcome is not unit-testable single-server)", function()
		-- The graceful handshake needs a second server to answer, so we only assert it returns a
		-- promise; its settlement is environment dependent and covered by real multi-server usage.
		local helper = newHelper()

		local promise = helper:PromiseCloseSessionGraceful(1, "some-other-job", "some-other-session")
		expect(promise).never.toBeNil()
	end)
end)

describe("DataStore.SetSessionMessagingEnabled wiring", function()
	it("should enable then disable session messaging without erroring", function()
		local serviceBag = ServiceBag.new()
		serviceBag:GetService(require("PlaceMessagingService"))
		serviceBag:Init()
		serviceBag:Start()

		local dataStore = DataStore.new(DataStoreMock.new(), "player_1")
		maid:GiveTask(function()
			dataStore:Destroy()
			serviceBag:Destroy()
		end)
		-- Messaging is documented to work alongside session locking; enable both like real usage.
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		expect(function()
			dataStore:SetSessionMessagingEnabled(true, serviceBag)
		end).never.toThrow()

		expect(function()
			dataStore:SetSessionMessagingEnabled(false)
		end).never.toThrow()
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
