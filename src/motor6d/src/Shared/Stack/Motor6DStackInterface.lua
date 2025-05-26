--[=[
	@class Motor6DStackInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("Motor6DStack", {
	TransformFromCFrame = TieDefinition.Types.METHOD,
	Push = TieDefinition.Types.METHOD,
})
