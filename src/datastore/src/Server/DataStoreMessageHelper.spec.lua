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

local DataStoreMessageHelper = require("DataStoreMessageHelper")
local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local MessagingServiceUtils = require("MessagingServiceUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("DataStoreMessageHelper.new", function()
	it("should construct against a real ServiceBag and DataStore", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newMessageHelper()

		expect(helper).never.toBeNil()

		controller:destroy()
	end)

	it("should expose the ServiceBag it was built with", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newMessageHelper()

		expect((helper:GetServiceBag() == controller.serviceBag)).toEqual(true)

		controller:destroy()
	end)

	it("should reject a nil serviceBag", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore()

		expect(function()
			DataStoreMessageHelper.new(nil, dataStore)
		end).toThrow("No serviceBag")

		controller:destroy()
	end)

	it("should not error on construct then Destroy", function()
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newMessageHelper()

		-- The test destroys the helper itself; the maid then skips it, so there is no double-Destroy.
		expect(function()
			helper:Destroy()
		end).never.toThrow()

		controller:destroy()
	end)
end)

describe("DataStoreMessageHelper.PromiseSendSessionMessage", function()
	it("should refuse to message its own session synchronously", function()
		local controller = DataStoreTestUtils.setup()
		local helper, dataStore = controller.newMessageHelper()

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
		local controller = DataStoreTestUtils.setup()
		local helper = controller.newMessageHelper()

		local promise = helper:PromiseCloseSessionGraceful(1, "some-other-job", "some-other-session")
		expect(promise).never.toBeNil()

		controller:destroy()
	end)
end)

describe("DataStore.SetSessionMessagingEnabled wiring", function()
	it("should enable then disable session messaging without erroring", function()
		local controller = DataStoreTestUtils.setup()
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
