--!nonstrict
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

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local service = serviceBag:GetService(require("TeleportDataServiceClient"))
	serviceBag:Init()

	return {
		service = service,
		destroy = function()
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
