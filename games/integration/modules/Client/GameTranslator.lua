--[=[
	@class GameTranslator
]=]

local require = require(script.Parent.loader).load(script)

return require("JSONTranslator").new("GameTranslator", "en", {
	actions = {
		ragdoll = "Ragdoll",
		unragdoll = "Unragdoll",
	}
})