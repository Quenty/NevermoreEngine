--[=[
	@class IKAimPositionPriorites
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	DEFAULT = 0,
	LOW = 1000,
	MEDIUM = 3000,
	HIGH = 4000,
})
