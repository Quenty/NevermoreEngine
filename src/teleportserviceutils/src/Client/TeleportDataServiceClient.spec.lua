--!strict
--[[
	Coverage for the client's arrived-data surface, mirroring the server's. GetLocalPlayerTeleportData and
	the server pull are unavailable in the headless test environment, so the local (non-trusted) band and
	the trusted band are both driven through the inject seams. The trusted band is always a subset of the
	local band in reality (local teleport data contains everything the player arrived with), and the tests
	preserve that relationship.

	@class TeleportDataServiceClient.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Maid = require("Maid")
local PromiseTestUtils = require("PromiseTestUtils")
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
	local service: TeleportDataServiceClient.TeleportDataServiceClient =
		serviceBag:GetService(TeleportDataServiceClient) :: any
	serviceBag:Init()

	-- Stand in a fixed local UserId: a headless client has no Players.LocalPlayer to key the slice by.
	local anyService = service :: any
	anyService._getLocalUserId = function()
		return LOCAL_USER_ID
	end

	return {
		service = service,
		await = function(promise: any): any
			expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
			local ok, value = promise:Yield()
			expect(ok).toEqual(true)
			return value
		end,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}
end

describe("TeleportDataServiceClient initialization", function()
	it("resolves to no arrived data outside a real teleport", function()
		local controller = setup()

		expect(controller.await(controller.service:PromiseArrivedData())).toBeNil()
		expect(controller.await(controller.service:PromiseHasArrivedValue("anything"))).toEqual(false)

		controller:destroy()
	end)
end)

describe("TeleportDataServiceClient unified arrived data", function()
	it("reads an injected flat local band immediately", function()
		local controller = setup()

		controller.service:SetNonTrustedArrivedTeleportDataForTesting({ slot = "a" })

		expect(controller.await(controller.service:PromiseArrivedData())).toEqual({ slot = "a" })
		expect(controller.await(controller.service:PromiseArrivedValue("slot"))).toEqual("a")
		expect(controller.await(controller.service:PromiseHasArrivedValue("slot"))).toEqual(true)

		controller:destroy()
	end)

	it("reports a missing key as absent", function()
		local controller = setup()

		controller.service:SetNonTrustedArrivedTeleportDataForTesting({ slot = "a" })

		expect(controller.await(controller.service:PromiseArrivedValue("missing"))).toBeNil()
		expect(controller.await(controller.service:PromiseHasArrivedValue("missing"))).toEqual(false)

		controller:destroy()
	end)

	it("unwraps the local player's own slice from an enveloped local band", function()
		local controller = setup()

		local envelope = TeleportDataEnvelopeUtils.build({ region = "shared" }, {
			[tostring(LOCAL_USER_ID)] = { slot = "mine" },
			[tostring(OTHER_USER_ID)] = { slot = "theirs" },
		})
		controller.service:SetNonTrustedArrivedTeleportDataForTesting(envelope)

		expect(controller.await(controller.service:PromiseArrivedData())).toEqual({
			region = "shared",
			slot = "mine",
		})

		controller:destroy()
	end)

	it("does not expose another player's slice", function()
		local controller = setup()

		local envelope = TeleportDataEnvelopeUtils.build(nil, {
			[tostring(OTHER_USER_ID)] = { slot = "theirs" },
		})
		controller.service:SetNonTrustedArrivedTeleportDataForTesting(envelope)

		expect(controller.await(controller.service:PromiseArrivedData())).toBeNil()
		expect(controller.await(controller.service:PromiseHasArrivedValue("slot"))).toEqual(false)

		controller:destroy()
	end)
end)

describe("TeleportDataServiceClient band separation", function()
	it("reads the trusted band pulled from the server", function()
		local controller = setup()

		controller.service:SetNonTrustedArrivedTeleportDataForTesting({ region = "us", slot = "client" })
		controller.service:SetTrustedArrivedTeleportDataForTesting({ region = "us" })

		expect(controller.await(controller.service:PromiseTrustedArrivedData())).toEqual({ region = "us" })
		expect(controller.await(controller.service:PromiseTrustedArrivedValue("region"))).toEqual("us")
		expect(controller.await(controller.service:PromiseHasTrustedArrivedValue("region"))).toEqual(true)
		expect(controller.await(controller.service:PromiseHasTrustedArrivedValue("slot"))).toEqual(false)

		controller:destroy()
	end)

	it("reads the non-trusted band as the full local view", function()
		local controller = setup()

		controller.service:SetNonTrustedArrivedTeleportDataForTesting({ region = "us", slot = "client" })
		controller.service:SetTrustedArrivedTeleportDataForTesting({ region = "us" })

		expect(controller.await(controller.service:PromiseNonTrustedArrivedData())).toEqual({
			region = "us",
			slot = "client",
		})

		controller:destroy()
	end)

	it("reports provenance against the server-pulled trusted band", function()
		local controller = setup()

		controller.service:SetNonTrustedArrivedTeleportDataForTesting({ region = "us", slot = "client" })
		controller.service:SetTrustedArrivedTeleportDataForTesting({ region = "us" })

		expect(controller.await(controller.service:PromiseArrivedValueIsTrusted("region"))).toEqual(true)
		expect(controller.await(controller.service:PromiseArrivedValueIsTrusted("slot"))).toEqual(false)

		controller:destroy()
	end)

	it("treats every local key as untrusted when the server proved nothing trusted", function()
		local controller = setup()

		controller.service:SetNonTrustedArrivedTeleportDataForTesting({ slot = "client" })
		controller.service:SetTrustedArrivedTeleportDataForTesting(nil)

		expect(controller.await(controller.service:PromiseTrustedArrivedData())).toBeNil()
		expect(controller.await(controller.service:PromiseArrivedValueIsTrusted("slot"))).toEqual(false)
		expect(controller.await(controller.service:PromiseArrivedValue("slot"))).toEqual("client")

		controller:destroy()
	end)
end)

describe("TeleportDataServiceClient build API (symmetric with the server)", function()
	it("builds an envelope through the same provider registry", function()
		local controller = setup()

		controller.service:RegisterPerPlayerTeleportDataProvider(function()
			return { slot = "built" }
		end)

		local fakeLocalPlayer = ({ UserId = LOCAL_USER_ID } :: any) :: Player
		local built = controller.service:BuildTeleportData({ fakeLocalPlayer })

		expect(TeleportDataEnvelopeUtils.readSlice(built, LOCAL_USER_ID)).toEqual({ slot = "built" })

		controller:destroy()
	end)
end)

describe("TeleportDataServiceClient inject-before-read invariant", function()
	it("rejects injecting the local band after a read", function()
		local controller = setup()

		controller.service:PromiseArrivedData()

		expect(function()
			controller.service:SetNonTrustedArrivedTeleportDataForTesting({ slot = "a" })
		end).toThrow()

		controller:destroy()
	end)

	it("rejects injecting the trusted band after a read", function()
		local controller = setup()

		controller.service:PromiseArrivedData()

		expect(function()
			controller.service:SetTrustedArrivedTeleportDataForTesting({ region = "us" })
		end).toThrow()

		controller:destroy()
	end)
end)
