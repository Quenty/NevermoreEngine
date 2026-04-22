--!strict
--[=[
    @class SoundGroupVolumeInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("SoundGroupVolume", {
	CreateMultiplier = TieDefinition.Types.METHOD,
})
