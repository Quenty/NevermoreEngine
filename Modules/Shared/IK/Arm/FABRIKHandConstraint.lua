---
-- @classmod FABRIKHandConstraint
-- @author Quenty

local FABRIKHandConstraint = {}
FABRIKHandConstraint.ClassName = "FABRIKHandConstraint"
FABRIKHandConstraint.__index = FABRIKHandConstraint

function FABRIKHandConstraint.new()
	local self = setmetatable({}, FABRIKHandConstraint)

	return self
end

function FABRIKHandConstraint:Constrain(lpoint, length)
	local unitlpoint = lpoint.unit
	local px, py, pz = unitlpoint.x, unitlpoint.y, unitlpoint.z

	px = px * 0.8
	py = py * 0.8

	return Vector3.new(px, py, pz).unit*length
end

return FABRIKHandConstraint