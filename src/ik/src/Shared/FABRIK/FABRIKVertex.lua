---
-- @classmod FABRIKVertex

local FABRIKVertex = {}
FABRIKVertex.__index = FABRIKVertex

function FABRIKVertex.new(point)
	local self = setmetatable({}, FABRIKVertex)

	self.Point = point

	return self
end

return FABRIKVertex