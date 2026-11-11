--!nonstrict
--[=[
	Handles product prompting state on the server

	@server
	@class PlayerProductManager
]=]

local require = require(script.Parent.loader).load(script)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local EnumUtils = require("EnumUtils")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameProductDataService = require("GameProductDataService")
local MarketplaceUtils = require("MarketplaceUtils")
local PlayerBinder = require("PlayerBinder")
local PlayerMock = require("PlayerMock")
local PlayerProductManagerBase = require("PlayerProductManagerBase")
local PlayerProductManagerInterface = require("PlayerProductManagerInterface")
local ReceiptProcessingService = require("ReceiptProcessingService")
local Remoting = require("Remoting")
local ServiceBag = require("ServiceBag")

local PlayerProductManager = setmetatable({}, PlayerProductManagerBase)
PlayerProductManager.ClassName = "PlayerProductManager"
PlayerProductManager.__index = PlayerProductManager

export type PlayerProductManager =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_receiptProcessingService: any, -- ReceiptProcessingService.ReceiptProcessingService
			_gameProductDataService: any, -- GameProductDataService.GameProductDataService
			_remoting: any,
		},
		{} :: typeof({ __index = PlayerProductManager })
	))
	& PlayerProductManagerBase.PlayerProductManagerBase

--[=[
	Managers players products and purchase state. Should be retrieved via binder.

	@param player Player
	@param serviceBag ServiceBag
	@return PlayerProductManager
]=]
function PlayerProductManager.new(player: Player, serviceBag: ServiceBag.ServiceBag): PlayerProductManager
	local self: PlayerProductManager =
		setmetatable(PlayerProductManagerBase.new(player, serviceBag) :: any, PlayerProductManager)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._receiptProcessingService = self._serviceBag:GetService(ReceiptProcessingService) :: any
	self._gameProductDataService = self._serviceBag:GetService(GameProductDataService) :: any

	-- Route internal setup through an `any` view: resolving these heavy-`self` method
	-- calls against the intersected type otherwise overwhelms the old solver.
	local selfAny = self :: any
	selfAny:_setupRemoting()

	-- Setup each ownership tracker
	selfAny:_setupAssetTracker()
	selfAny:_setupMembershipTracker()
	selfAny:_setupSubscriptionTracker()
	selfAny:_setupProductTracker()
	selfAny:_setupPassTracker()
	selfAny:_setupBundleTracker()

	-- Initialize attributes

	local serverOnlyPrompting = self._gameProductDataService:GetServerOnlyPromptingValue()
	self._maid:GiveTask(serverOnlyPrompting:Observe():Subscribe(function(value)
		self._obj:SetAttribute(GameProductDataService.ServerOnlyPromptingAttribute, value)
	end))

	-- Implement
	local impl = self._maid:Add(PlayerProductManagerInterface.Server:Implement(self._obj, self))
	selfAny:ExportMarketTrackers(impl:GetImplParent())

	return self
end

function PlayerProductManager._setupRemoting(self: PlayerProductManager): ()
	self._remoting =
		self._maid:Add((Remoting.Server :: any).new(self._obj, "PlayerProductManager", Remoting.Realms.SERVER))
end

function PlayerProductManager._setupAssetTracker(self: PlayerProductManager): ()
	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.ASSET) :: any

	self._maid:GiveTask(self._remoting.AssetPromptPurchaseFinished:Connect(function(player, assetId, isPurchased)
		assert(self._obj == player, "Bad player")
		assert(type(assetId) == "number", "Bad assetId")
		assert(type(isPurchased) == "boolean", "Bad isPurchased")

		-- TODO: Validate on server
		tracker:HandlePromptClosedEvent(assetId, isPurchased)
		tracker:HandlePurchaseEvent(assetId, isPurchased)
	end))
end

function PlayerProductManager._setupProductTracker(self: PlayerProductManager): ()
	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.PRODUCT) :: any

	-- Source of truth for purchase is here
	self._remoting.DeveloperProductPurchased:DeclareEvent()

	self._maid:GiveTask(self._remoting.PromptProductPurchaseFinished:Connect(function(player, productId, isPurchased)
		assert(self._obj == player, "Bad player")

		tracker:HandlePromptClosedEvent(productId)

		-- We only read from the server purchase event
		if not isPurchased then
			tracker:HandlePurchaseEvent(productId, isPurchased)
		end
	end))

	self._maid:GiveTask(
		(self._receiptProcessingService:ObserveReceiptProcessedForPlayer(self._obj) :: any):Subscribe(
			function(receiptInfo, productPurchaseDecision)
				assert(type(receiptInfo) == "table", "Bad receiptInfo")
				assert(EnumUtils.isOfType(Enum.ProductPurchaseDecision, productPurchaseDecision), "Bad decision")

				local productId = receiptInfo.ProductId
				tracker:HandlePurchaseEvent(productId, true)

				self._remoting.DeveloperProductPurchased:FireClient(self._obj, productId)
			end
		)
	)
end

function PlayerProductManager._setupPassTracker(self: PlayerProductManager): ()
	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.PASS) :: any

	self._maid:GiveTask(self._remoting.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, isPurchased)
		assert(player == self._obj, "Bad player")
		assert(type(gamePassId) == "number", "Bad gamePassId")
		assert(type(isPurchased) == "boolean", "Bad isPurchased")

		-- Closing the prompt is safe to take on the client's word: it only unblocks pending prompt
		-- state and grants nothing.
		tracker:HandlePromptClosedEvent(gamePassId)

		if not isPurchased then
			tracker:HandlePurchaseEvent(gamePassId, false)
			return
		end

		-- Verification rides on server-only prompting rather than a switch of its own. Enabling it is a
		-- game saying the server drives purchases, which is also what makes the ownership check safe to
		-- pay for. Left off, this stays on the client's word -- knowingly, because
		-- UserOwnsGamePassAsync answers from a per-server cache that can still read `false` for the
		-- purchase that just completed, and denying on that stale read loses a pass the player paid for.
		-- See [GameProductService.SetServerOnlyPromptingEnabled].
		if not self._gameProductDataService:GetServerOnlyPromptingValue().Value then
			tracker:HandlePurchaseEvent(gamePassId, true)
			return
		end

		-- The purchase itself is not. This event is fired by the client, so `isPurchased == true` is an
		-- unverified claim -- a client can fire it for any gamepass id without ever paying, and granting
		-- ownership on it hands the pass out for free. Confirm against the marketplace before it counts,
		-- so only a pass the player genuinely owns is recorded as purchased.
		local userId = if PlayerMock.isMock(self._obj) then PlayerMock.read(self._obj, "UserId") else self._obj.UserId

		self._maid:GivePromise(MarketplaceUtils.promiseUserOwnsGamePass(userId, gamePassId)):Then(function(ownsPass)
			tracker:HandlePurchaseEvent(gamePassId, ownsPass == true)
		end, function(err)
			-- The ownership check could not answer (a marketplace hiccup, not a purchase). Grant nothing
			-- on the failure, and resolve the pending prompt as unbought so a server-initiated caller is
			-- not left waiting forever.
			warn(
				string.format(
					"[PlayerProductManager] - Failed to verify gamepass %d ownership for %s: %s",
					gamePassId,
					tostring(self._obj),
					tostring(err)
				)
			)
			tracker:HandlePurchaseEvent(gamePassId, false)
		end)
	end))
end

function PlayerProductManager._setupMembershipTracker(self: PlayerProductManager): ()
	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.MEMBERSHIP) :: any

	self._maid:GiveTask(Players.PlayerMembershipChanged:Connect(function(player)
		if player == self._obj then
			if player.MembershipType == Enum.MembershipType.Premium then
				tracker:HandlePurchaseEvent(player.MembershipType, true)
			end
		end
	end))
end

function PlayerProductManager._setupSubscriptionTracker(self: PlayerProductManager): ()
	self._remoting.UserSubscriptionStatusChanged:DeclareEvent()

	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.SUBSCRIPTION) :: any

	self._maid:GiveTask(self._remoting.PromptSubscriptionPurchaseFinished:Connect(function(player, subscriptionId)
		assert(player == self._obj, "Bad player")

		tracker:HandlePromptClosedEvent(subscriptionId)
	end))

	-- In case this does anything
	self._maid:GiveTask(
		MarketplaceService.PromptSubscriptionPurchaseFinished:Connect(function(player, subscriptionId, didTryPurchasing)
			if player == self._obj then
				tracker:HandlePromptClosedEvent(subscriptionId)
				self._remoting.PromptSubscriptionPurchaseFinished:FireClient(player, subscriptionId, didTryPurchasing)

				if not didTryPurchasing then
					tracker:HandlePurchaseEvent(subscriptionId, didTryPurchasing)
				end
			end
		end)
	)

	self._maid:GiveTask(Players.UserSubscriptionStatusChanged:Connect(function(player, subscriptionId)
		if player == self._obj then
			tracker:HandlePurchaseEvent(subscriptionId)
			self._remoting.UserSubscriptionStatusChanged:FireClient(player, subscriptionId)
		end
	end))
end

function PlayerProductManager._setupBundleTracker(self: PlayerProductManager): ()
	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.BUNDLE) :: any

	self._maid:GiveTask(MarketplaceService.PromptBundlePurchaseFinished:Connect(function(player, bundleId, isPurchased)
		if player == self._obj then
			tracker:HandlePromptClosedEvent(bundleId)
			tracker:HandlePurchaseEvent(bundleId, isPurchased)
		end
	end))

	self._maid:GiveTask(self._remoting.PromptBundlePurchaseFinished:Connect(function(player, bundleId, isPurchased)
		assert(player == self._obj, "Bad player")
		assert(type(bundleId) == "number", "Bad bundleId")
		assert(type(isPurchased) == "boolean", "Bad isPurchased")

		tracker:HandlePromptClosedEvent(bundleId)
		tracker:HandlePurchaseEvent(bundleId, isPurchased)
	end))
end

return PlayerBinder.new(
		"PlayerProductManager",
		PlayerProductManager :: any
	) :: PlayerBinder.PlayerBinder<PlayerProductManager>
