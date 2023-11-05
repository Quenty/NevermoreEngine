--[=[
	Handles cmdr integration
	@class GameConfigCommandService
]=]

local require = require(script.Parent.loader).load(script)

local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")

local GameConfigCmdrUtils = require("GameConfigCmdrUtils")
local BadgeUtils = require("BadgeUtils")
local PlayerUtils = require("PlayerUtils")

local GameConfigCommandService = {}
GameConfigCommandService.ServiceName = "GameConfigCommandService"

function GameConfigCommandService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._cmdrService = self._serviceBag:GetService(require("CmdrService"))
	self._gameConfigService = self._serviceBag:GetService(require("GameConfigService"))
end

function GameConfigCommandService:Start()
	self:_registerCommands()
end

function GameConfigCommandService:_registerCommands()
	local configPicker = self._gameConfigService:GetConfigPicker()
	assert(configPicker, "No configPicker")

	self._cmdrService:PromiseCmdr():Then(function(cmdr)
		GameConfigCmdrUtils.registerAssetTypes(cmdr, configPicker)
	end)

	self._cmdrService:RegisterCommand({
		Name = "give-badge";
		Aliases = { "award-badge" };
		Description = "Awards the player a badge.";
		Group = "GameConfig";
		Args = {
			{
				Name = "Targets";
				Type = "players";
				Description = "The player to award.";
			},
			{
				Name = "Badge";
				Type = "badgeIds";
				Description = "Badge to award.";
			},
		};
	}, function(_context, players, badgeIds)
		local givenTo = {}

		for _, player in pairs(players) do
			for _, badgeId in pairs(badgeIds) do
				BadgeUtils.promiseAwardBadge(player, badgeId)
				table.insert(givenTo, string.format("%s badge %d", PlayerUtils.formatName(player), badgeId))
			end
		end

		return string.format("Awards: %s", table.concat(givenTo, ", "))
	end)

	self._cmdrService:RegisterCommand({
		Name = "prompt-product";
		Description = "Prompts the player to make a product purchase.";
		Group = "GameConfig";
		Args = {
			{
				Name = "Player";
				Type = "players";
				Description = "The player to prompt.";
			},
			{
				Name = "Product";
				Type = "productId";
				Description = "The Product to prompt.";
			},
		};
	}, function(_context, players, productId)
		local givenTo = {}

		for _, player in pairs(players) do
			MarketplaceService:PromptProductPurchase(player, productId)
			table.insert(givenTo, string.format("%s prompted purchase of %d", PlayerUtils.formatName(player), productId))
		end

		return string.format("Prompted: %s", table.concat(givenTo, ", "))
	end)

	self._cmdrService:RegisterCommand({
		Name = "prompt-pass";
		Description = "Prompts the player to make a gamepass purchase.";
		Group = "GameConfig";
		Args = {
			{
				Name = "Player";
				Type = "players";
				Description = "The player to prompt.";
			},
			{
				Name = "GamePass";
				Type = "passId";
				Description = "The gamepass to prompt.";
			},
		};
	}, function(_context, players, gamePassId)
		local givenTo = {}

		for _, player in pairs(players) do
			MarketplaceService:PromptGamePassPurchase(player, gamePassId)
			table.insert(givenTo, string.format("%s prompted purchase of %d", PlayerUtils.formatName(player), gamePassId))
		end

		return string.format("Prompted: %s", table.concat(givenTo, ", "))
	end)

	self._cmdrService:RegisterCommand({
		Name = "prompt-asset";
		Description = "Prompts the player to make an asset purchase.";
		Group = "GameConfig";
		Args = {
			{
				Name = "Player";
				Type = "players";
				Description = "The player to prompt.";
			},
			{
				Name = "Asset";
				Type = "assetId";
				Description = "The asset to prompt.";
			},
		};
	}, function(_context, players, assetId)
		local givenTo = {}

		for _, player in pairs(players) do
			MarketplaceService:PromptPurchase(player, assetId)
			table.insert(givenTo, string.format("%s prompted purchase of %d", PlayerUtils.formatName(player), assetId))
		end

		return string.format("Prompted: %s", table.concat(givenTo, ", "))
	end)

	self._cmdrService:RegisterCommand({
		Name = "prompt-bundle";
		Description = "Prompts the player to make a bundle purchase.";
		Group = "GameConfig";
		Args = {
			{
				Name = "Player";
				Type = "players";
				Description = "The player to prompt.";
			},
			{
				Name = "Bundle";
				Type = "bundleId";
				Description = "The asset to prompt.";
			},
		};
	}, function(_context, players, bundleId)
		local givenTo = {}

		for _, player in pairs(players) do
			MarketplaceService:PromptBundlePurchase(player, bundleId)
			table.insert(givenTo, string.format("%s prompted purchase of %d", PlayerUtils.formatName(player), bundleId))
		end

		return string.format("Prompted: %s", table.concat(givenTo, ", "))
	end)

	self._cmdrService:RegisterCommand({
		Name = "goto-named-place";
		Description = "Teleport to a Roblox place.";
		Group = "GameConfig";
		Args = {
			{
				Type = "players";
				Name = "Players";
				Description = "The players you want to teleport";
			},
			{
				Type = "placeId";
				Name = "Place";
				Description = "The Place you want to teleport to";
			},
			{
				Type = "string";
				Name = "JobId";
				Description = "The specific JobId you want to teleport to";
				Optional = true;
			}
		};
	}, function(context, players, placeId, jobId)
		if placeId <= 0 then
			return "Invalid place ID"
		elseif jobId == "-" then
			return "Invalid job ID"
		end

		context:Reply("Commencing teleport...")

		if jobId then
			for _, player in pairs(players) do
				TeleportService:TeleportToPlaceInstance(placeId, jobId, player)
			end
		else
			TeleportService:TeleportPartyAsync(placeId, players)
		end

		return "Teleported."
	end)
end

return GameConfigCommandService