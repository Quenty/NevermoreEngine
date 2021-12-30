--[=[
	@class GameTranslator
]=]

local require = require(script.Parent.loader).load(script)

return require("JSONTranslator").new("en", {
	actions = {
		ragdoll = "Ragdoll",
		unragdoll = "Unragdoll",
	}
})