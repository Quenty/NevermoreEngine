--[=[
	Centralize receipt processing within games since this is a constrained resource.

	@class ReceiptProcessingService
]=]

local require = require(script.Parent.loader).load(script)

local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local EnumUtils = require("EnumUtils")
local Maid = require("Maid")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")
local Promise = require("Promise")
local Signal = require("Signal")
local ValueObject = require("ValueObject")
local _ServiceBag = require("ServiceBag")
local _Observable = require("Observable")

export type ReceiptInfo = {
	PurchaseId: number,
	PlayerId: number,
	ProductId: number,
	PlaceIdWherePurchased: number,
	CurrencySpent: number,
	CurrencyType: Enum.CurrencyType,
	ProductPurchaseChannel: Enum.ProductPurchaseChannel,
}

local ReceiptProcessingService = {}
ReceiptProcessingService.ServiceName = "ReceiptProcessingService"

function ReceiptProcessingService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self.ReceiptCreated = self._maid:Add(Signal.new()) -- :Fire(receiptInfo)
	self.ReceiptProcessed = self._maid:Add(Signal.new()) -- :Fire(receiptInfo, productPurchaseDecision)

	self._receiptProcessedForUserId = self._maid:Add(ObservableSubscriptionTable.new()) -- :Fire(receiptInfo, productPurchaseDecision)
	self._defaultDecision = self._maid:Add(ValueObject.new(Enum.ProductPurchaseDecision.PurchaseGranted, "EnumItem"))

	self._processors = {}
end

function ReceiptProcessingService:Start()
	if RunService:IsServer() then
		MarketplaceService.ProcessReceipt = function(...)
			return self:_handleProcessReceiptAsync(...)
		end
	end
end

--[=[
	Sets the default purchase decision in case you want more control
	@param productPurchaseDecision ProductPurchaseDecision
]=]
function ReceiptProcessingService:SetDefaultPurchaseDecision(productPurchaseDecision: Enum.ProductPurchaseDecision)
	assert(EnumUtils.isOfType(Enum.ProductPurchaseDecision, productPurchaseDecision), "Bad productPurchaseDecision")

	self._defaultDecision.Value = productPurchaseDecision
end

--[=[
	Observes receipt by player

	@param player Player
	@return Observable<ReceiptInfo>
]=]
function ReceiptProcessingService:ObserveReceiptProcessedForPlayer(player: Player): _Observable.Observable<ReceiptInfo>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self:ObserveReceiptProcessedForUserId(player.UserId)
end
--[=[
	Observes receipt by userId

	@param userId number
	@return Observable<ReceiptInfo>
]=]
function ReceiptProcessingService:ObserveReceiptProcessedForUserId(userId: number): _Observable.Observable<ReceiptInfo>
	assert(type(userId) == "number", "Bad userId")

	return self._receiptProcessedForUserId:Observe(userId)
end

export type ReceiptProcessor = (
	receiptInfo: ReceiptInfo
) -> Enum.ProductPurchaseDecision? | Promise.Promise<Enum.ProductPurchaseDecision?>

--[=[
	Registers a new receipt processor. This works exactly like a normal receipt processor except it will also
	take a Promise as a result (of which an error).

	@param processor (receiptInfo) -> ProductPurchaseDecision | Promise<ProductPurchaseDecision> | nil
	@param priority number?
]=]
function ReceiptProcessingService:RegisterReceiptProcessor(processor: ReceiptProcessor, priority: number?): () -> ()
	assert(self._processors, "Not initialized")
	assert(type(processor) == "function", "Bad processor")
	priority = priority or 0

	local data = {
		traceback = debug.traceback(),
		priority = priority,
		timestamp = os.clock(),
		processor = processor,
	}

	table.insert(self._processors, data)
	table.sort(self._processors, function(a, b)
		if a.priority ~= b.priority then
			-- larger priority first
			return a.priority > b.priority
		else
			-- earlier first
			return a.timestamp < b.timestamp
		end
	end)

	return function()
		local index = table.find(self._handles, data)
		if index then
			table.remove(self._handles, index)
		end
	end
end

function ReceiptProcessingService:_handleProcessReceiptAsync(receiptInfo: ReceiptInfo): Enum.ProductPurchaseDecision
	if not self._processors then
		warn(
			"[ReceiptProcessingService._handleProcessReceiptAsync] - We're leaking memory. Receipt processing service is already cleaned up."
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	self.ReceiptCreated:Fire(receiptInfo)

	-- Chain of command this thing
	for _, data in self._processors do
		local result = data.processor(receiptInfo)

		-- Unpack pro
		if Promise.isPromise(result) then
			local ok, promiseResult = result:Yield()
			if not ok then
				warn(
					string.format(
						"[ReceiptProcessingService._handleProcessReceiptAsync] - Promise failed with %q.\n%s",
						tostring(promiseResult),
						data.traceback
					)
				)
				continue
			end

			result = promiseResult
		end

		if EnumUtils.isOfType(Enum.ProductPurchaseDecision, result) then
			self:_fireProcessed(receiptInfo, result)
			return result
		elseif result == nil then
			continue
		else
			warn(
				string.format(
					"[ReceiptProcessingService._handleProcessReceiptAsync] - Got unexpected result of type %q from receiptInfo.\n%s",
					typeof(result),
					data.traceback
				)
			)
		end
	end

	-- Retry in the future
	self:_fireProcessed(receiptInfo, self._defaultDecision.Value)
	return self._defaultDecision.Value
end

function ReceiptProcessingService:_fireProcessed(receiptInfo: ReceiptInfo, productPurchaseDecision: Enum.ProductPurchaseDecision)
	assert(EnumUtils.isOfType(Enum.ProductPurchaseDecision, productPurchaseDecision), "Bad productPurchaseDecision")

	self.ReceiptProcessed:Fire(receiptInfo, productPurchaseDecision)

	if type(receiptInfo.PlayerId) == "number" then
		self._receiptProcessedForUserId:Fire(receiptInfo.PlayerId, receiptInfo, productPurchaseDecision)
	else
		warn("[ReceiptProcessingService._fireProcessed] - No receiptInfo.PlayerId")
	end
end

function ReceiptProcessingService:Destroy()
	self._maid:DoCleaning()
	self._processors = nil
end

return ReceiptProcessingService
