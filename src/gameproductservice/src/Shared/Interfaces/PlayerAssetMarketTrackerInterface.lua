--[=[
	@class PlayerAssetMarketTrackerInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("PlayerAssetMarketTracker", {
	ObservePromptOpenCount = TieDefinition.Types.METHOD;
	ObserveAssetPurchased = TieDefinition.Types.METHOD;
	PromisePromptPurchase = TieDefinition.Types.METHOD;
	HasPurchasedThisSession = TieDefinition.Types.METHOD;
	IsPromptOpen = TieDefinition.Types.METHOD;

	Purchased = TieDefinition.Types.SIGNAL;
	PromptClosed = TieDefinition.Types.SIGNAL;
	ShowPromptRequested = TieDefinition.Types.SIGNAL;
})