---
-- @module NumberRangeUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local NumberRangeUtils = {}

function NumberRangeUtils.scale(range, scale)
	return NumberRange.new(range.Min*scale, range.Max*scale)
end

return NumberRangeUtils