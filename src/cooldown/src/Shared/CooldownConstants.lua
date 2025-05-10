--!strict
--[=[
	Holds constants for the cooldown.
	@class CooldownConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	COOLDOWN_TIME_NAME = "CooldownTime",
	COOLDOWN_START_TIME_ATTRIBUTE = "CooldownStartTime",
})
