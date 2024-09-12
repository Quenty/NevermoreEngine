--[=[
	@class PlayerProductManagerInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("PlayerProductManager", {
	GetPlayer = TieDefinition.Types.METHOD;
	IsOwnable = TieDefinition.Types.METHOD;
	IsPromptOpen = TieDefinition.Types.METHOD;
	PromisePlayerPromptClosed = TieDefinition.Types.METHOD;
	GetAssetTrackerOrError = TieDefinition.Types.METHOD;
	GetOwnershipTrackerOrError = TieDefinition.Types.METHOD;
})