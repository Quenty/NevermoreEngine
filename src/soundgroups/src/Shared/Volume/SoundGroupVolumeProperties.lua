--!strict
--[=[
	@class SoundGroupVolumeProperties
]=]

local require = require(script.Parent.loader).load(script)

local RoguePropertyTableDefinition = require("RoguePropertyTableDefinition")

return RoguePropertyTableDefinition.new("SoundGroupVolume", {
	Volume = 1,
})
