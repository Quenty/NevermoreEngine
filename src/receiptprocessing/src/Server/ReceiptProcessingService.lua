--[=[
	Centralize receipt processing within games since this is a constrained resource.

	@class ReceiptProcessingService
]=]

local require = require(script.Parent.loader).load(script)

local MarketplaceService = game:GetService("MarketplaceService")

local Promise = require("Promise")
local EnumUtils = require("EnumUtils")
local Signal = require("Signal")
local Maid = require("Maid")

local ReceiptProcessingService = {}
ReceiptProcessingService.ServiceName = "ReceiptProcessingService"

function ReceiptProcessingService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self.ReceiptCreated = Signal.new() -- :Fire(receiptInfo)
	self._maid:GiveTask(self.ReceiptCreated)

	self.ReceiptProcessed = Signal.new() -- :Fire(receiptInfo, productPurchaseDecision)
	self._maid:GiveTask(self.ReceiptProcessed)

	self._processors = {}
end

function ReceiptProcessingService:Start()
	MarketplaceService.ProcessReceipt = function(...)
		return self:_handleProcessReceiptAsync(...)
	end
end

--[=[
	Registers a new receipt processor. This works exactly like a normal receipt processor except it will also
	take a Promise as a result (of which an error).

	@param processor (receiptInfo) -> ProductPurchaseDecision | Promise<ProductPurchaseDecision> | nil
	@param priority number
]=]
function ReceiptProcessingService:RegisterReceiptProcessor(processor, priority)
	assert(self._processors, "Not initialized")
	assert(type(processor) == "function", "Bad processor")
	priority = priority or 0

	local data = {
		traceback = debug.traceback();
		priority = priority;
		timestamp = os.clock();
		processor = processor;
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
			table.remove(self._handles, data)
		end
	end
end

function ReceiptProcessingService:_handleProcessReceiptAsync(receiptInfo)
	if not self._processors then
		warn("[ReceiptProcessingService._handleProcessReceiptAsync] - We're leaking memory. Receipt processing service is already cleaned up.")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	self.ReceiptCreated:Fire(receiptInfo)

	-- Chain of command this thing
	for _, data in pairs(self._processors) do
		local result = data.processor(receiptInfo)

		-- Unpack pro
		if Promise.isPromise(result) then
			local ok, promiseResult = result:Yield()
			if not ok then
				warn(string.format("[ReceiptProcessingService._handleProcessReceiptAsync] - Promise failed with %q.\n%s", tostring(promiseResult), data.traceback))
				continue
			end

			result = promiseResult
		end

		if EnumUtils.isOfType(Enum.ProductPurchaseDecision, result) then
			self.ReceiptProcessed:Fire(receiptInfo, result)
			return result
		elseif result == nil then
			continue
		else
			warn(string.format("[ReceiptProcessingService._handleProcessReceiptAsync] - Got unexpected result of type %q from receiptInfo.\n%s", typeof(result), data.traceback))
		end
	end

	-- Retry in the future
	self.ReceiptProcessed:Fire(receiptInfo, Enum.ProductPurchaseDecision.NotProcessedYet)
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function ReceiptProcessingService:Destroy()
	self._maid:DoCleaning()
	self._processors = nil
end

return ReceiptProcessingService