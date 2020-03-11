---
-- @module IKAimPositionPriorites
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Table = require("Table")

return Table.readonly({
	DEFAULT = 0;
	LOW = 1000;
	MEDIUM = 3000;
	HIGH = 4000;
})