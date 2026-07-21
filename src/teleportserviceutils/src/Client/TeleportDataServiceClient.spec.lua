--!strict
--[[
	Coverage for TeleportDataServiceClient's arrived-data accessors. GetLocalPlayerTeleportData is
	unavailable in the headless test environment (no real teleport), so arrived data is exercised
	through the test seam.

	@class TeleportDataServiceClient.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local TeleportDataEnvelopeUtils = require("TeleportDataEnvelopeUtils")
local TeleportDataServiceClient = require("TeleportDataServiceClient")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local LOCAL_USER_ID = 111
local OTHER_USER_ID = 222

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local service = (
		serviceBag:GetService(TeleportDataServiceClient) :: any
	) :: TeleportDataServiceClient.TeleportDataServiceClient
	serviceBag:Init()

	-- Stand in a fixed local UserId: a headless client has no Players.LocalPlayer to key the slice by.
	local anyService = service :: any
	anyService._getLocalUserId = function()
		return LOCAL_USER_ID
	end

	return {
		service = service,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}
end

describe("TeleportDataServiceClient initialization", function()
	it("should initialize with no arrived data outside a real teleport", function()
		local controller = setup()

		expect(controller.service:GetArrivedTeleportData()).toBeNil()
		expect(controller.service:HasArrivedValue("anything")).toEqual(false)

		controller:destroy()
	end)
end)

describe("TeleportDataServiceClient arrived data", function()
	it("should read an injected arrived value", function()
		local controller = setup()

		controller.service:SetArrivedTeleportDataForTesting({ key = "value" })

		expect(controller.service:GetArrivedTeleportData()).toEqual({ key = "value" })
		expect(controller.service:GetArrivedValue("key")).toEqual("value")
		expect(controller.service:HasArrivedValue("key")).toEqual(true)

		controller:destroy()
	end)

	it("should report a missing key as absent", function()
		local controller = setup()

		controller.service:SetArrivedTeleportDataForTesting({ key = "value" })

		expect(controller.service:GetArrivedValue("other")).toBeNil()
		expect(controller.service:HasArrivedValue("other")).toEqual(false)

		controller:destroy()
	end)

	it("should clear an injected override back to nil", function()
		local controller = setup()

		controller.service:SetArrivedTeleportDataForTesting({ key = "value" })
		controller.service:SetArrivedTeleportDataForTesting(nil)

		expect(controller.service:GetArrivedTeleportData()).toBeNil()
		expect(controller.service:HasArrivedValue("key")).toEqual(false)

		controller:destroy()
	end)

	it("should reject injecting an override after the data has been read", function()
		local controller = setup()

		controller.service:GetArrivedTeleportData() -- consumes it (resolves to nil headless)

		expect(function()
			controller.service:SetArrivedTeleportDataForTesting({ key = "value" })
		end).toThrow("after it has been read")

		controller:destroy()
	end)
end)

describe("TeleportDataServiceClient enveloped arrived data", function()
	it("should unwrap the local player's slice merged with the shared slice", function()
		local controller = setup()

		local envelope = TeleportDataEnvelopeUtils.build({ region = "shared" }, {
			[tostring(LOCAL_USER_ID)] = { IncomingSaveSlotId = "slot-mine" },
			[tostring(OTHER_USER_ID)] = { IncomingSaveSlotId = "slot-theirs" },
		})
		controller.service:SetArrivedTeleportDataForTesting(envelope)

		expect(controller.service:GetArrivedTeleportData()).toEqual({
			region = "shared",
			IncomingSaveSlotId = "slot-mine",
		})
		expect(controller.service:GetArrivedValue("IncomingSaveSlotId")).toEqual("slot-mine")
		expect(controller.service:HasArrivedValue("IncomingSaveSlotId")).toEqual(true)

		controller:destroy()
	end)

	it("should not expose another player's slice", function()
		local controller = setup()

		local envelope = TeleportDataEnvelopeUtils.build(nil, {
			[tostring(OTHER_USER_ID)] = { IncomingSaveSlotId = "slot-theirs" },
		})
		controller.service:SetArrivedTeleportDataForTesting(envelope)

		-- No shared slice and no slice for our UserId, so we arrived carrying nothing.
		expect(controller.service:GetArrivedTeleportData()).toBeNil()
		expect(controller.service:HasArrivedValue("IncomingSaveSlotId")).toEqual(false)

		controller:destroy()
	end)

	it("should let a per-player slice override a shared key", function()
		local controller = setup()

		local envelope = TeleportDataEnvelopeUtils.build(
			{ IncomingSaveSlotId = "slot-shared" },
			{ [tostring(LOCAL_USER_ID)] = { IncomingSaveSlotId = "slot-mine" } }
		)
		controller.service:SetArrivedTeleportDataForTesting(envelope)

		expect(controller.service:GetArrivedValue("IncomingSaveSlotId")).toEqual("slot-mine")

		controller:destroy()
	end)

	it("should still read legacy flat data as-is (no envelope, no UserId needed)", function()
		local controller = setup()

		-- A flat table is not an envelope, so the local UserId is never consulted.
		local localUserIdConsulted = false
		local anyService = controller.service :: any
		anyService._getLocalUserId = function()
			localUserIdConsulted = true
			return LOCAL_USER_ID
		end

		controller.service:SetArrivedTeleportDataForTesting({ IncomingSaveSlotId = "slot-flat" })

		expect(controller.service:GetArrivedValue("IncomingSaveSlotId")).toEqual("slot-flat")
		expect(localUserIdConsulted).toEqual(false)

		controller:destroy()
	end)
end)
