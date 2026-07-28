--!strict
--[[
	The processor chain, driven directly rather than through MarketplaceService: Start is what installs
	the engine callback, and nothing here needs the engine to route a receipt.

	@class ReceiptProcessingService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Maid = require("Maid")
local ReceiptProcessingService = require("ReceiptProcessingService")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function receiptInfo(productId: number): any
	return {
		PurchaseId = 1,
		PlayerId = 55234567,
		ProductId = productId,
		PlaceIdWherePurchased = 1,
		CurrencySpent = 100,
		CurrencyType = Enum.CurrencyType.Robux,
		ProductPurchaseChannel = Enum.ProductPurchaseChannel.InExperience,
	}
end

local function setup()
	local maid = Maid.new()

	local serviceBag = maid:Add(ServiceBag.new())
	local service = serviceBag:GetService(ReceiptProcessingService) :: any

	serviceBag:Init()

	return {
		maid = maid,
		service = service,
	}
end

describe("ReceiptProcessingService.RegisterReceiptProcessor", function()
	it("routes receipts to the registered processor", function()
		local context = setup()

		local seen = {}
		context.service:RegisterReceiptProcessor(function(info)
			table.insert(seen, info.ProductId)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end)

		expect(context.service:_handleProcessReceiptAsync(receiptInfo(11))).toBe(
			Enum.ProductPurchaseDecision.PurchaseGranted
		)
		expect(seen).toEqual({ 11 })

		context.maid:DoCleaning()
	end)

	it("stops routing once the returned unregister is called", function()
		local context = setup()

		local calls = 0
		local unregister = context.service:RegisterReceiptProcessor(function()
			calls += 1
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end)

		context.service:_handleProcessReceiptAsync(receiptInfo(11))
		unregister()
		context.service:_handleProcessReceiptAsync(receiptInfo(11))

		expect(calls).toBe(1)

		context.maid:DoCleaning()
	end)

	it("unregisters only its own processor", function()
		local context = setup()

		local otherCalls = 0
		context.service:RegisterReceiptProcessor(function()
			otherCalls += 1
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end)

		local unregister = context.service:RegisterReceiptProcessor(function()
			return nil
		end)
		unregister()

		context.service:_handleProcessReceiptAsync(receiptInfo(11))

		expect(otherCalls).toBe(1)

		context.maid:DoCleaning()
	end)

	-- A maid holding the unregister as a task runs it during teardown, after Destroy has cleared the list.
	-- Throwing there takes the rest of the teardown down with it.
	it("survives being called after the service is destroyed", function()
		local context = setup()

		local unregister = context.service:RegisterReceiptProcessor(function()
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end)

		context.maid:DoCleaning()

		expect(function()
			unregister()
		end).never.toThrow()
	end)
end)
