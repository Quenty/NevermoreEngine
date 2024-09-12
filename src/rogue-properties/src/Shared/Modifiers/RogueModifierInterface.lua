--[=[
	@class RogueModifierInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("RogueModifier", {
	Order = TieDefinition.Types.PROPERTY;
	Source = TieDefinition.Types.PROPERTY;

	--
	GetModifiedVersion = TieDefinition.Types.METHOD;
	ObserveModifiedVersion = TieDefinition.Types.METHOD;
	GetInvertedVersion = TieDefinition.Types.METHOD;
})