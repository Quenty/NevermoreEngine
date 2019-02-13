--- ScrollType enum, determines scrolling behavior
-- @module ScrollType

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Table = require("Table")

return Table.ReadOnly({
	Vertical = { Direction = "y" };
	Horizontal = { Direction = "x" };
})