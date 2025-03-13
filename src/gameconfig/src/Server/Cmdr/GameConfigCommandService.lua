--[=[
	Handles cmdr integration
	@class GameConfigCommandService
]=]

local require = require(script.Parent.loader).load(script)

local TeleportService = game:GetService("TeleportService")

local GameConfigCmdrUtils = require("GameConfigCmdrUtils")
local BadgeUtils = require("BadgeUtils")
local PlayerUtils = require("PlayerUtils")
local _ServiceBag = require("ServiceBag")

local GameConfigCommandService = {}
GameConfigCommandService.ServiceName = "GameConfigCommandService"

function GameConfigCommandService:Init(serviceBag: _ServiceBag.ServiceBag)
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

		for _, player in players do
			for _, badgeId in badgeIds do
				BadgeUtils.promiseAwardBadge(player, badgeId)
				table.insert(givenTo, string.format("%s badge %d", PlayerUtils.formatName(player), badgeId))
			end
		end

		return string.format("Awards: %s", table.concat(givenTo, ", "))
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
			for _, player in players do
				TeleportService:TeleportToPlaceInstance(placeId, jobId, player)
			end
		else
			TeleportService:TeleportPartyAsync(placeId, players)
		end

		return "Teleported."
	end)
end

return GameConfigCommandService