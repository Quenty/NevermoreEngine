--[=[
	@class PlayerSettingsInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("PlayerSettings", {
	GetSettingProperty = TieDefinition.Types.METHOD;
	GetValue = TieDefinition.Types.METHOD;
	SetValue = TieDefinition.Types.METHOD;
	ObserveValue = TieDefinition.Types.METHOD;
	RestoreDefault = TieDefinition.Types.METHOD;
	EnsureInitialized = TieDefinition.Types.METHOD;
	GetPlayer = TieDefinition.Types.METHOD;
})