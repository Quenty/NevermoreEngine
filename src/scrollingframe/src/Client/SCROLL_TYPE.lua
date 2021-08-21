--- ScrollType enum, determines scrolling behavior
-- @module ScrollType

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	Vertical = { Direction = "y" };
	Horizontal = { Direction = "x" };
})