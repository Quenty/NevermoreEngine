--!strict
--[[
	Coverage for the server's arrived-data surface: the two trust bands, the unified merge, the
	pend-until-replicated / timeout-fallback lifecycle, and first-wins sealing. A headless cloud test
	server has no joined players and no join data, so both the UserId keying and each band are driven
	through the inject seams rather than a real teleport. The replication *transport* (Remoting) is not
	exercised here -- only the logic behind it.

	@class TeleportDataService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")
local TeleportDataEnvelopeUtils = require("TeleportDataEnvelopeUtils")
local TeleportDataService = require("TeleportDataService")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local service: TeleportDataService.TeleportDataService = serviceBag:GetService(TeleportDataService) :: any
	serviceBag:Init()

	return {
		service = service,
		fakePlayer = function(userId: number?): Player
			return maid:Add(PlayerMock.new(if userId ~= nil then { UserId = userId } else nil))
		end,
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

describe("TeleportDataService.BuildTeleportData (delegates to the shared builder)", function()
	it("assembles a per-player envelope readable by UserId", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:RegisterPerPlayerTeleportDataProvider(function(givenPlayer)
			return { slot = "slot-" .. tostring(givenPlayer:GetAttribute("UserId")) }
		end)

		local built = controller.service:BuildTeleportData({ player })
		expect(TeleportDataEnvelopeUtils.readSlice(built, 111)).toEqual({ slot = "slot-111" })

		controller:destroy()
	end)

	it("carries base data under a shared provider key", function()
		local controller = setup()

		controller.service:RegisterTeleportDataProvider(function()
			return { shared = "provider" }
		end)

		local built = controller.service:BuildTeleportData({}, { shared = "caller" })
		expect(TeleportDataEnvelopeUtils.readSlice(built, 111)).toEqual({ shared = "caller" })

		controller:destroy()
	end)
end)

describe("TeleportDataService unified arrived data", function()
	it("reads the trusted band alone when nothing was replicated", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:SetTrustedArrivedTeleportDataForTesting(player, { region = "us" })
		controller.service:SetNonTrustedArrivedTeleportDataForTesting(player, nil)

		expect(controller.await(controller.service:PromiseArrivedData(player))).toEqual({ region = "us" })

		controller:destroy()
	end)

	it("reads the non-trusted band alone when there is no trusted band", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		local envelope = TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "client" } })
		controller.service:SetNonTrustedArrivedTeleportDataForTesting(player, envelope)

		expect(controller.await(controller.service:PromiseArrivedData(player))).toEqual({ slot = "client" })

		controller:destroy()
	end)

	it("unions disjoint keys across both bands", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:SetTrustedArrivedTeleportDataForTesting(player, { region = "us" })
		local envelope = TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "client" } })
		controller.service:SetNonTrustedArrivedTeleportDataForTesting(player, envelope)

		expect(controller.await(controller.service:PromiseArrivedData(player))).toEqual({
			region = "us",
			slot = "client",
		})

		controller:destroy()
	end)

	it("lets the trusted band win on a key conflict (client cannot override the server)", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:SetTrustedArrivedTeleportDataForTesting(player, { slot = "server-slot" })
		local envelope = TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "client-slot" } })
		controller.service:SetNonTrustedArrivedTeleportDataForTesting(player, envelope)

		expect(controller.await(controller.service:PromiseArrivedValue(player, "slot"))).toEqual("server-slot")

		controller:destroy()
	end)
end)

describe("TeleportDataService band separation", function()
	it("exposes only the trusted band through the trusted accessors", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:SetTrustedArrivedTeleportDataForTesting(player, { region = "us" })
		local envelope = TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "client" } })
		controller.service:SetNonTrustedArrivedTeleportDataForTesting(player, envelope)

		expect(controller.await(controller.service:PromiseTrustedArrivedData(player))).toEqual({ region = "us" })
		expect(controller.await(controller.service:PromiseTrustedArrivedValue(player, "slot"))).toBeNil()
		expect(controller.await(controller.service:PromiseHasTrustedArrivedValue(player, "region"))).toEqual(true)
		expect(controller.await(controller.service:PromiseHasTrustedArrivedValue(player, "slot"))).toEqual(false)

		controller:destroy()
	end)

	it("exposes only the non-trusted band through the non-trusted accessor", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:SetTrustedArrivedTeleportDataForTesting(player, { region = "us" })
		local envelope = TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "client" } })
		controller.service:SetNonTrustedArrivedTeleportDataForTesting(player, envelope)

		expect(controller.await(controller.service:PromiseNonTrustedArrivedData(player))).toEqual({ slot = "client" })

		controller:destroy()
	end)

	it("reports provenance: a trusted key is trusted, a client-only key is not", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:SetTrustedArrivedTeleportDataForTesting(player, { region = "us" })
		local envelope = TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "client" } })
		controller.service:SetNonTrustedArrivedTeleportDataForTesting(player, envelope)

		expect(controller.await(controller.service:PromiseArrivedValueIsTrusted(player, "region"))).toEqual(true)
		expect(controller.await(controller.service:PromiseArrivedValueIsTrusted(player, "slot"))).toEqual(false)

		controller:destroy()
	end)

	it("reports a conflicting key as trusted (the trusted value is the one that wins)", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:SetTrustedArrivedTeleportDataForTesting(player, { slot = "server" })
		local envelope = TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "client" } })
		controller.service:SetNonTrustedArrivedTeleportDataForTesting(player, envelope)

		expect(controller.await(controller.service:PromiseArrivedValueIsTrusted(player, "slot"))).toEqual(true)

		controller:destroy()
	end)
end)

describe("TeleportDataService value accessors", function()
	it("reports presence and absence of a unified value", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:SetNonTrustedArrivedTeleportDataForTesting(
			player,
			TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "a" } })
		)

		expect(controller.await(controller.service:PromiseArrivedValue(player, "slot"))).toEqual("a")
		expect(controller.await(controller.service:PromiseArrivedValue(player, "missing"))).toBeNil()
		expect(controller.await(controller.service:PromiseHasArrivedValue(player, "slot"))).toEqual(true)
		expect(controller.await(controller.service:PromiseHasArrivedValue(player, "missing"))).toEqual(false)

		controller:destroy()
	end)
end)

describe("TeleportDataService per-player replication", function()
	it("gives each player only their own slice from the same replicated envelope", function()
		local controller = setup()
		local playerA = controller.fakePlayer(111)
		local playerB = controller.fakePlayer(222)

		local envelope = TeleportDataEnvelopeUtils.build(nil, {
			["111"] = { slot = "a" },
			["222"] = { slot = "b" },
		})
		controller.service:SetNonTrustedArrivedTeleportDataForTesting(playerA, envelope)
		controller.service:SetNonTrustedArrivedTeleportDataForTesting(playerB, envelope)

		expect(controller.await(controller.service:PromiseArrivedValue(playerA, "slot"))).toEqual("a")
		expect(controller.await(controller.service:PromiseArrivedValue(playerB, "slot"))).toEqual("b")

		controller:destroy()
	end)
end)

describe("TeleportDataService arrival lifecycle", function()
	it("pends the unified read until the client replicates, then resolves", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:SetTrustedArrivedTeleportDataForTesting(player, { region = "us" })

		local promise = controller.service:PromiseArrivedData(player)
		expect(promise:IsPending()).toEqual(true)

		controller.service:SetNonTrustedArrivedTeleportDataForTesting(
			player,
			TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "client" } })
		)

		expect(controller.await(promise)).toEqual({ region = "us", slot = "client" })

		controller:destroy()
	end)

	it("falls back to the trusted band alone when replication never arrives (timeout)", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		-- Arm a tiny timeout *before* the entry is created (the timer is armed on first touch).
		controller.service:SetReplicationTimeoutForTesting(0.1)
		controller.service:SetTrustedArrivedTeleportDataForTesting(player, { region = "us" })

		local promise = controller.service:PromiseArrivedData(player)
		expect(promise:IsPending()).toEqual(true)

		expect(controller.await(promise)).toEqual({ region = "us" })

		controller:destroy()
	end)

	it("resolves promptly for a mock with nothing injected -- there is no client to wait for", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		expect(controller.await(controller.service:PromiseArrivedData(player))).toBeNil()

		controller:destroy()
	end)

	it("seals on the first replication -- a later one is ignored (first wins)", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:SetNonTrustedArrivedTeleportDataForTesting(
			player,
			TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "first" } })
		)
		controller.service:SetNonTrustedArrivedTeleportDataForTesting(
			player,
			TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "second" } })
		)

		expect(controller.await(controller.service:PromiseArrivedValue(player, "slot"))).toEqual("first")

		controller:destroy()
	end)

	it("gives every reader the same sealed answer", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		local pendingRead = controller.service:PromiseArrivedValue(player, "slot")
		controller.service:SetNonTrustedArrivedTeleportDataForTesting(
			player,
			TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "a" } })
		)
		local laterRead = controller.service:PromiseArrivedValue(player, "slot")

		expect(controller.await(pendingRead)).toEqual("a")
		expect(controller.await(laterRead)).toEqual("a")

		controller:destroy()
	end)
end)

describe("TeleportDataService inject-before-read invariant", function()
	it("rejects injecting a trusted override after a read has been requested", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:PromiseArrivedData(player)

		expect(function()
			controller.service:SetTrustedArrivedTeleportDataForTesting(player, { region = "us" })
		end).toThrow()

		controller:destroy()
	end)

	it("rejects injecting a trusted override after the arrival has sealed", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:SetNonTrustedArrivedTeleportDataForTesting(player, nil) -- seals

		expect(function()
			controller.service:SetTrustedArrivedTeleportDataForTesting(player, { region = "us" })
		end).toThrow()

		controller:destroy()
	end)
end)
