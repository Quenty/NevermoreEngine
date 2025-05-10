--!strict
--[=[
	@class WellKnownSoundGroups
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

export type WellKnownSoundGroups = {
	MASTER: "Master",
	SFX: "Master.SoundEffects",
	MUSIC: "Master.Music",
	VOICE: "Master.Voice",
}

return Table.readonly({
	MASTER = "Master",

	SFX = "Master.SoundEffects",
	MUSIC = "Master.Music",
	VOICE = "Master.Voice",
} :: WellKnownSoundGroups)
