--[=[
	This service provides an interface to purchase produces, assets, and other
	marketplace items. This listens to events, handles requests between server and
	client, and takes in both assetKeys from GameConfigService, as well as
	assetIds.

	See [GameProductServiceClient] for the client equivalent. The API surface should be
	effectively the same between the two.

	@server
	@class GameProductService
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local _ServiceBag = require("ServiceBag")
local _Observable = require("Observable")
local _GameConfigAssetTypes = require("GameConfigAssetTypes")
local _Promise = require("Promise")
local _Signal = require("Signal")
local _GameProductDataService = require("GameProductDataService")

local GameProductService = {}
GameProductService.ServiceName = "GameProductService"

export type GameProductService = typeof(setmetatable(
	{} :: {
		_serviceBag: _ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_gameProductDataService: _GameProductDataService.GameProductDataService,

		GamePassPurchased: _Signal.Signal<Player, number>,
		ProductPurchased: _Signal.Signal<Player, number>,
		AssetPurchased: _Signal.Signal<Player, number>,
		BundlePurchased: _Signal.Signal<Player, number>,
		MembershipPurchased: _Signal.Signal<Player, number>,
		SubscriptionPurchased: _Signal.Signal<Player, number>,
	},
	{} :: typeof({ __index = GameProductService })
))

--[=[
	Initializes the service. Should be done via [ServiceBag]
	@param serviceBag ServiceBag
]=]
function GameProductService.Init(self: GameProductService, serviceBag: _ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("GameConfigService"))
	self._serviceBag:GetService(require("CatalogSearchServiceCache"))
	self._serviceBag:GetService(require("ReceiptProcessingService"))
	self._serviceBag:GetService(require("CmdrService"))

	-- Internal
	self._gameProductDataService = self._serviceBag:GetService(require("GameProductDataService"))
	self._serviceBag:GetService(require("PlayerProductManager"))
	self._serviceBag:GetService((require :: any)("GameProductCmdrService"))

	-- Additional API for ergonomics
	self.GamePassPurchased = assert(self._gameProductDataService.GamePassPurchased, "No GamePassPurchased") -- :Fire(player, gamePassId)
	self.ProductPurchased = assert(self._gameProductDataService.ProductPurchased, "No ProductPurchased") -- :Fire(player, productId)
	self.AssetPurchased = assert(self._gameProductDataService.AssetPurchased, "No AssetPurchased") -- :Fire(player, assetId)
	self.BundlePurchased = assert(self._gameProductDataService.BundlePurchased, "No BundlePurchased") -- :Fire(player, bundleId)
	self.MembershipPurchased = assert(self._gameProductDataService.MembershipPurchased, "No MembershipPurchased") -- :Fire(player, assetId)
	self.SubscriptionPurchased = assert(self._gameProductDataService.SubscriptionPurchased, "No SubscriptionPurchased") -- :Fire(player, bundleId)
end

--[=[
	Fires when the specified player purchases an asset

	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Observable<>
]=]
function GameProductService.ObservePlayerAssetPurchased(
	self: GameProductService,
	player: Player,
	assetType: _GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): _Observable.Observable<()>
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:ObservePlayerAssetPurchased(player, assetType, idOrKey)
end

--[=[
	Fires when any player purchases an asset

	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Observable<Player>
]=]
function GameProductService.ObserveAssetPurchased(
	self: GameProductService,
	assetType: _GameConfigAssetTypes.GameConfigAssetType,
	idOrKey
): _Observable.Observable<Player>
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:ObserveAssetPurchased(assetType, idOrKey)
end

--[=[
	Returns true if item has been purchased this session

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return boolean
]=]
function GameProductService.HasPlayerPurchasedThisSession(
	self: GameProductService,
	player: Player,
	assetType: _GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): boolean
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:HasPlayerPurchasedThisSession(player, assetType, idOrKey)
end

--[=[
	Returns true if the prompt is open

	@param player Player
	@return Promise<boolean>
]=]
function GameProductService.PromisePlayerIsPromptOpen(
	self: GameProductService,
	player: Player
): _Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(self._serviceBag, "Not initialized")

	return self._gameProductDataService:PromisePlayerIsPromptOpen(player)
end

--[=[
	Returns a promise that will resolve when all prompts are closed

	@param player Player
	@return Promise
]=]
function GameProductService.PromisePlayerPromptClosed(
	self: GameProductService,
	player: Player
): _Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(self._serviceBag, "Not initialized")

	return self._gameProductDataService:PromisePlayerPromptClosed(player)
end

--[=[
	Prompts the user to purchase the asset, and returns true if purchased

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return boolean
]=]
function GameProductService.PromisePlayerPromptPurchase(
	self: GameProductService,
	player: Player,
	assetType: _GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): _Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:PromisePromptPurchase(player, assetType, idOrKey)
end

--[=[
	Returns true if item has been purchased this session

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Promise<boolean>
]=]
function GameProductService.PromisePlayerOwnership(
	self: GameProductService,
	player: Player,
	assetType: _GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): _Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:PromisePlayerOwnership(player, assetType, idOrKey)
end

--[=[
	Checks if the asset is ownable and if it is, checks player ownership. Otherwise, it checks if the asset
	has been purchased this session. If the asset has not been purchased this session it prompts the user to
	purchase the item.

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Promise<boolean>
]=]
function GameProductService.PromisePlayerOwnershipOrPrompt(
	self: GameProductService,
	player: Player,
	assetType: _GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): _Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:PromisePlayerOwnershipOrPrompt(player, assetType, idOrKey)
end

--[=[
	Observes if the player owns this cloud asset or not

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Observable<boolean>
]=]
function GameProductService.ObservePlayerOwnership(
	self: GameProductService,
	player: Player,
	assetType: _GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): _Observable.Observable<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:ObservePlayerOwnership(player, assetType, idOrKey)
end

--[=[
	Cleans up the game product service
]=]
function GameProductService.Destroy(self: GameProductService)
	self._maid:DoCleaning()
end

return GameProductService
