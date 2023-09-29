--[[
	@class ChatProviderTranslator
]]

local require = require(script.Parent.loader).load(script)

return require("JSONTranslator").new("ChatProviderTranslator", "en", {
	chatTags = {
		dev = "(dev)";
		mod = "(mod)";
	};
})