--[=[
	@class PermissionLevel
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	ADMIN = "admin";
	CREATOR = "creator";
})