--!nonstrict
--[[
	Integration coverage for GameProductDataService driven through a real ServiceBag. Only
	GameProductDataService (and its dependency TieRealmService) is registered, so the heavy
	binder/MarketplaceService graph is never started. This focuses on the pieces that do not
	require a live Player: the exported purchase signals, the server-only prompting ValueObject,
	and the prompt guard's realm behavior. The realm is forced explicitly so the test is not
	sensitive to where the runner executes.

	@class GameProductDataService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")
local Signal = require("Signal")
local TieRealms = require("TieRealms")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(tieRealm)
	local serviceBag = ServiceBag.new()
	local tieRealmService = serviceBag:GetService(require("TieRealmService"))
	local gameProductDataService = serviceBag:GetService(require("GameProductDataService"))
	serviceBag:Init()
	tieRealmService:SetTieRealm(tieRealm or TieRealms.SERVER)
	serviceBag:Start()

	return {
		serviceBag = serviceBag,
		tieRealmService = tieRealmService,
		gameProductDataService = gameProductDataService,
		destroy = function()
			serviceBag:Destroy()
		end,
	}
end

describe("GameProductDataService purchase signals", function()
	it("should expose the six purchase signals after init", function()
		local context = setup()
		local service = context.gameProductDataService

		for _, signalName in
			{
				"GamePassPurchased",
				"ProductPurchased",
				"AssetPurchased",
				"BundlePurchased",
				"SubscriptionPurchased",
				"MembershipPurchased",
			}
		do
			expect(Signal.isSignal(service[signalName])).toEqual(true)
		end

		context.destroy()
	end)
end)

describe("GameProductDataService server-only prompting", function()
	it("should default to disabled", function()
		local context = setup()
		expect(context.gameProductDataService:GetServerOnlyPromptingValue().Value).toEqual(false)
		context.destroy()
	end)

	it("should enable and disable via SetServerOnlyPrompting on the server", function()
		local context = setup()
		local service = context.gameProductDataService

		service:SetServerOnlyPrompting(true)
		expect(service:GetServerOnlyPromptingValue().Value).toEqual(true)

		service:SetServerOnlyPrompting(false)
		expect(service:GetServerOnlyPromptingValue().Value).toEqual(false)
		context.destroy()
	end)

	it("should replicate the change through the ValueObject observable", function()
		local context = setup()
		local service = context.gameProductDataService

		local values = {}
		local sub = service:GetServerOnlyPromptingValue():Observe():Subscribe(function(value)
			table.insert(values, value)
		end)

		service:SetServerOnlyPrompting(true)
		sub:Destroy()

		expect(values[1]).toEqual(false)
		expect(values[#values]).toEqual(true)
		context.destroy()
	end)

	it("should reject a non-boolean argument", function()
		local context = setup()
		local service = context.gameProductDataService

		expect(function()
			service:SetServerOnlyPrompting("nope")
		end).toThrow()
		context.destroy()
	end)

	it("should refuse to configure server-only prompting from the client realm", function()
		local context = setup(TieRealms.CLIENT)
		local service = context.gameProductDataService

		expect(function()
			service:SetServerOnlyPrompting(true)
		end).toThrow()
		context.destroy()
	end)
end)

describe("GameProductDataService prompt guard", function()
	it("should resolve immediately on the server realm", function()
		local context = setup(TieRealms.SERVER)
		local service = context.gameProductDataService

		local fakePlayer = Instance.new("Folder")
		local outcome = PromiseTestUtils.awaitOutcome(service:_promiseServerOnlyPromptingGuard(fakePlayer), 5)
		expect(outcome).toEqual("resolved")

		fakePlayer:Destroy()
		context.destroy()
	end)
end)
