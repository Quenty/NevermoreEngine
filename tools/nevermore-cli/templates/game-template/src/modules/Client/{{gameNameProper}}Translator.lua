--[[
	@class {{gameNameProper}}Translator
]]

local require = require(script.Parent.loader).load(script)

return require("JSONTranslator").new("{{gameNameProper}}Translator", "en", {
	gameName = "{{gameNameProper}}";
})