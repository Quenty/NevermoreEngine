--[=[
	@class CooldownConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	COOLDOWN_NAME = "Cooldown";
	COOLDOWN_TIME_NAME = "CooldownTime";
	COOLDOWN_START_TIME_NAME = "CooldownStartTime";
})