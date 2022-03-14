--[=[
	@class GameProductService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local GameProductServiceBase = require("GameProductServiceBase")
local Maid = require("Maid")

local GameProductService = GameProductServiceBase.new()

function GameProductService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._gameConfigService = self._serviceBag:GetService(require("GameConfigService"))

	-- Internal
	self._binders = self._serviceBag:GetService(require("GameProductBindersServer"))
end

function GameProductService:Start()
	MarketplaceService.ProcessReceipt = function(...)
		return self:_processReceipt(...)
	end
end

function GameProductService:GetPlayerProductManagerBinder()
	return self._binders.PlayerProductManager
end

function GameProductService:_processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- The player probably left the game
		-- If they come back, the callback will be called again
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productManager = self._binders.PlayerProductManager:Get(player)
	if productManager then
		return productManager:HandleProcessReceipt(player, receiptInfo)
	end

	-- Free money?
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return GameProductService