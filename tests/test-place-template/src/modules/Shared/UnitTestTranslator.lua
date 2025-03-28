--[[
	@class UnitTestTranslator
]]

local require = require(script.Parent.loader).load(script)

return require("JSONTranslator").new("UnitTestTranslator", "en", {
	gameName = "UnitTest";
})