--[[
	Provides translations for game configuration
	@class GameConfigTranslator
]]

local require = require(script.Parent.loader).load(script)

return require("JSONTranslator").new("GameConfigTranslator", "en", {
	assetKeys = {
		name = {
			unknown = "???";
		};
		description = {
			unknown = "???";
		};
	};
})