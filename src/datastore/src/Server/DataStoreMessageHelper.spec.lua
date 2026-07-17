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

-- Builds a real ServiceBag plus DataStores and helpers over it, all owned by a Maid, so destroy()
-- tears down every object the test created. newDataStore() builds a plain store; newHelper() wires a
-- DataStoreMessageHelper to a fresh store off the shared bag.
local function setup()
	local maid = Maid.new()

	local serviceBag = maid:Add(ServiceBag.new())
	-- The helper pulls PlaceMessagingService off the bag; register it before Start.
	serviceBag:GetService(require("PlaceMessagingService"))
	serviceBag:Init()
	serviceBag:Start()

	local function newDataStore()
		return maid:Add(DataStore.new(DataStoreMock.new(), "player_1"))
	end

	local function newHelper()
		local dataStore = newDataStore()
		-- The helper only reads GetSessionId()/GetKey() off the store, both of which a plain
		-- DataStore provides (the session id is a GUID assigned in DataStore.new).
		local helper = maid:Add(DataStoreMessageHelper.new(serviceBag, dataStore))
		return helper, dataStore
	end

	return {
		serviceBag = serviceBag,
		newDataStore = newDataStore,
		newHelper = newHelper,
		destroy = function()
			maid:DoCleaning()
		end,
	}
end

describe("DataStoreMessageHelper.new", function()
	it("should construct against a real ServiceBag and DataStore", function()
		local controller = setup()
		local helper = controller.newHelper()

		expect(helper).never.toBeNil()

		controller:destroy()
	end)

	it("should expose the ServiceBag it was built with", function()
		local controller = setup()
		local helper = controller.newHelper()

		expect((helper:GetServiceBag() == controller.serviceBag)).toEqual(true)

		controller:destroy()
	end)

	it("should reject a nil serviceBag", function()
		local controller = setup()
		local dataStore = controller.newDataStore()

		expect(function()
			DataStoreMessageHelper.new(nil, dataStore)
		end).toThrow("No serviceBag")

		controller:destroy()
	end)

	it("should not error on construct then Destroy", function()
		local controller = setup()
		local helper = controller.newHelper()

		-- The test destroys the helper itself; the maid then skips it, so there is no double-Destroy.
		expect(function()
			helper:Destroy()
		end).never.toThrow()

		controller:destroy()
	end)
end)

describe("DataStoreMessageHelper.PromiseSendSessionMessage", function()
	it("should refuse to message its own session synchronously", function()
		local controller = setup()
		local helper, dataStore = controller.newHelper()

		local ownSessionId = dataStore:GetSessionId()
		expect(function()
			helper:PromiseSendSessionMessage(1, "job", ownSessionId, {
				type = "close-session",
				requesterSessionId = ownSessionId,
			})
		end).toThrow("Cannot message self")

		controller:destroy()
	end)
end)

describe("DataStoreMessageHelper.PromiseCloseSessionGraceful", function()
	it("should return a promise (cross-server outcome is not unit-testable single-server)", function()
		-- The graceful handshake needs a second server to answer, so we only assert it returns a
		-- promise; its settlement is environment dependent and covered by real multi-server usage.
		local controller = setup()
		local helper = controller.newHelper()

		local promise = helper:PromiseCloseSessionGraceful(1, "some-other-job", "some-other-session")
		expect(promise).never.toBeNil()

		controller:destroy()
	end)
end)

describe("DataStore.SetSessionMessagingEnabled wiring", function()
	it("should enable then disable session messaging without erroring", function()
		local controller = setup()
		local dataStore = controller.newDataStore()
		-- Messaging is documented to work alongside session locking; enable both like real usage.
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		expect(function()
			dataStore:SetSessionMessagingEnabled(true, controller.serviceBag)
		end).never.toThrow()

		expect(function()
			dataStore:SetSessionMessagingEnabled(false)
		end).never.toThrow()

		controller:destroy()
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
