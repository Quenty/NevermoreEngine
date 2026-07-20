--!strict
--[=[
	@class GameProductCmdrService
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local PlayerUtils = require("PlayerUtils")
local ServiceBag = require("ServiceBag")

local GameProductCmdrService = {}
GameProductCmdrService.ServiceName = "GameProductCmdrService"

-- Asset types that have an ownership tracker (see PlayerProductManagerBase). Only these can
-- have their ownership overridden.
local OWNABLE_ASSET_TYPES: { [string]: boolean } = {
	[GameConfigAssetTypes.PASS] = true,
	[GameConfigAssetTypes.ASSET] = true,
	[GameConfigAssetTypes.BUNDLE] = true,
	[GameConfigAssetTypes.SUBSCRIPTION] = true,
	[GameConfigAssetTypes.MEMBERSHIP] = true,
	[GameConfigAssetTypes.GAME] = true,
}

export type GameProductCmdrService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_cmdrService: any,
		_gameProductService: any,
	},
	{} :: typeof({ __index = GameProductCmdrService })
))

function GameProductCmdrService.Init(self: GameProductCmdrService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._cmdrService = self._serviceBag:GetService(require("CmdrService"))
	self._gameProductService = self._serviceBag:GetService(require("GameProductService"))
end

function GameProductCmdrService.Start(self: GameProductCmdrService): ()
	self:_registerCommands()
end

function GameProductCmdrService._registerCommands(self: GameProductCmdrService): ()
	self._cmdrService:RegisterCommand({
		Name = "prompt-product",
		Description = "Prompts the player to make a product purchase game-product-service.",
		Group = "GameConfig",
		Args = {
			{
				Name = "Player",
				Type = "players",
				Description = "The player to prompt.",
			},
			{
				Name = "Product",
				Type = "productId",
				Description = "The Product to prompt.",
			},
		},
	}, function(_context, players, productId)
		local givenTo = {}

		for _, player in players do
			self._gameProductService
				:PromisePlayerPromptPurchase(player, GameConfigAssetTypes.PRODUCT, productId)
				:Then(function(isPurchased)
					print(
						string.format(
							"User %s product purchase done. isPurchased: %s",
							PlayerUtils.formatName(player),
							tostring(isPurchased)
						)
					)
				end)

			table.insert(
				givenTo,
				string.format("%s prompted purchase of %d", PlayerUtils.formatName(player), productId)
			)
		end

		return string.format("Prompted: %s", table.concat(givenTo, ", "))
	end)

	self._cmdrService:RegisterCommand({
		Name = "prompt-pass",
		Description = "Prompts the player to make a gamepass purchase.",
		Group = "GameConfig",
		Args = {
			{
				Name = "Player",
				Type = "players",
				Description = "The player to prompt.",
			},
			{
				Name = "GamePass",
				Type = "passId",
				Description = "The gamepass to prompt.",
			},
		},
	}, function(_context, players, gamePassId)
		local givenTo = {}

		for _, player in players do
			self._gameProductService
				:PromisePlayerPromptPurchase(player, GameConfigAssetTypes.PASS, gamePassId)
				:Then(function(isPurchased)
					print(
						string.format(
							"User %s pass prompt done. isPurchased: %s",
							PlayerUtils.formatName(player),
							tostring(isPurchased)
						)
					)
				end)

			table.insert(
				givenTo,
				string.format("%s prompted purchase of %d", PlayerUtils.formatName(player), gamePassId)
			)
		end

		return string.format("Prompted: %s", table.concat(givenTo, ", "))
	end)

	self._cmdrService:RegisterCommand({
		Name = "prompt-asset",
		Description = "Prompts the player to make an asset purchase.",
		Group = "GameConfig",
		Args = {
			{
				Name = "Player",
				Type = "players",
				Description = "The player to prompt.",
			},
			{
				Name = "Asset",
				Type = "assetId",
				Description = "The asset to prompt.",
			},
		},
	}, function(_context, players, assetId)
		local givenTo = {}

		for _, player in players do
			self._gameProductService
				:PromisePlayerPromptPurchase(player, GameConfigAssetTypes.ASSET, assetId)
				:Then(function(isPurchased)
					print(
						string.format(
							"User %s asset prompt done. isPurchased: %s",
							PlayerUtils.formatName(player),
							tostring(isPurchased)
						)
					)
				end)

			table.insert(givenTo, string.format("%s prompted purchase of %d", PlayerUtils.formatName(player), assetId))
		end

		return string.format("Prompted: %s", table.concat(givenTo, ", "))
	end)

	self._cmdrService:RegisterCommand({
		Name = "prompt-bundle",
		Description = "Prompts the player to make a bundle purchase.",
		Group = "GameConfig",
		Args = {
			{
				Name = "Player",
				Type = "players",
				Description = "The player to prompt.",
			},
			{
				Name = "Bundle",
				Type = "bundleId",
				Description = "The asset to prompt.",
			},
		},
	}, function(_context, players, bundleId)
		local givenTo = {}

		for _, player in players do
			self._gameProductService
				:PromisePlayerPromptPurchase(player, GameConfigAssetTypes.BUNDLE, bundleId)
				:Then(function(isPurchased)
					print(
						string.format(
							"User %s bundle prompt done. isPurchased: %s",
							PlayerUtils.formatName(player),
							tostring(isPurchased)
						)
					)
				end)
			table.insert(givenTo, string.format("%s prompted purchase of %d", PlayerUtils.formatName(player), bundleId))
		end

		return string.format("Prompted: %s", table.concat(givenTo, ", "))
	end)

	self._cmdrService:RegisterCommand({
		Name = "set-ownership",
		Description = "Overrides a player's local ownership of an asset. Useful for testing ownership-gated "
			.. "behavior, including paid-access games which cannot be prompted in-experience.",
		Group = "GameConfig",
		Args = {
			{
				Name = "Player",
				Type = "players",
				Description = "The player(s) to override ownership for.",
			},
			{
				Name = "AssetType",
				Type = "string",
				Description = "Ownable asset type: game, pass, asset, bundle, subscription, or membership.",
			},
			{
				Name = "AssetIdOrKey",
				Type = "string",
				Description = "The asset id (number) or GameConfig asset key.",
			},
			{
				Name = "State",
				Type = "string",
				Description = "own (force owned), disown (force not owned), or clear (remove the override).",
			},
		},
	}, function(_context, players, assetType, assetIdOrKey, state)
		assetType = string.lower(assetType)
		if not GameConfigAssetTypeUtils.isAssetType(assetType) then
			return string.format("Unknown asset type %q", tostring(assetType))
		end

		if not OWNABLE_ASSET_TYPES[assetType] then
			return string.format("Asset type %q is not ownable", tostring(assetType))
		end

		state = string.lower(state)
		local ownsAsset: boolean?
		if state == "own" then
			ownsAsset = true
		elseif state == "disown" then
			ownsAsset = false
		elseif state == "clear" then
			ownsAsset = nil
		else
			return string.format("Unknown state %q (expected own, disown, or clear)", tostring(state))
		end

		-- Numeric ids arrive as strings from cmdr; coerce so raw asset ids resolve directly,
		-- while GameConfig keys pass through as strings.
		local idOrKey = tonumber(assetIdOrKey) or assetIdOrKey

		local ownableAssetType = assetType :: GameConfigAssetTypes.GameConfigAssetType

		local appliedTo = {}
		for _, player in players do
			self._gameProductService
				:SetPlayerOwnershipOverride(player, ownableAssetType, idOrKey, ownsAsset)
				:Catch(function(err)
					warn(
						string.format(
							"[set-ownership] - Failed for %s: %s",
							PlayerUtils.formatName(player),
							tostring(err)
						)
					)
				end)

			table.insert(appliedTo, PlayerUtils.formatName(player))
		end

		local verb = if ownsAsset == nil then "Cleared" elseif ownsAsset then "Granted" else "Revoked"
		return string.format(
			"%s %s ownership of %s for %s",
			verb,
			assetType,
			tostring(idOrKey),
			table.concat(appliedTo, ", ")
		)
	end)
end

return GameProductCmdrService
