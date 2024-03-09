--[=[
	@class WellKnownSoundGroups
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	MASTER = "Master";

	SFX = "Master.SoundEffects";
	MUSIC = "Master.Music";
	VOICE = "Master.Voice";
})