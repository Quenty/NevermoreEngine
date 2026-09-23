--!strict
--[=[
	@class SaveSlotUtils
]=]

local require = require(script.Parent.loader).load(script)

local SaveSlotData = require("SaveSlotData")

local SaveSlotUtils = {}

--[=[
	The name a slot gets when it is created without one, or when its name is cleared.
]=]
function SaveSlotUtils.getDefaultSlotName(slotIndex: number): string
	assert(type(slotIndex) == "number", "Bad slotIndex")

	return `Slot {slotIndex}`
end

--[=[
	Seconds the slot has been played, current as of `now` (defaults to `os.time()`). `TimePlayed`
	only lands on the slot when its data saves or its session ends, so for the active slot the
	running session is re-derived: the total minus the part of it already credited to this session,
	plus the wall time since the slot was selected. It never reads below the credited total, so a
	client clock behind the server's cannot make it go backwards.
]=]
function SaveSlotUtils.getTimePlayed(metadata: SaveSlotData.SaveSlotMetadata, isActive: boolean, now: number?): number
	assert(type(metadata) == "table", "Bad metadata")
	assert(type(isActive) == "boolean", "Bad isActive")

	local timePlayed = metadata.TimePlayed or 0
	if not isActive or metadata.LastPlayedTime == nil then
		return timePlayed
	end

	local beforeSession = timePlayed - (metadata.LastSessionLength or 0)
	local sessionLength = (now or os.time()) - metadata.LastPlayedTime
	return math.max(timePlayed, beforeSession + sessionLength)
end

return SaveSlotUtils
