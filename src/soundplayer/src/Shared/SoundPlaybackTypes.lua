--[=[
	@class SoundPlaybackTypes
]=]

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Table = require("Table")

return Table.readonly({
	STATIC_LOOPED_PLAYBACK = "staticLooped";
	SPORADIC_PLAYBACK = "sporadic";
})