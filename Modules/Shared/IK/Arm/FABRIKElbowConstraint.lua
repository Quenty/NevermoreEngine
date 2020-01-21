---
-- @classmod FABRIKElbowConstraint
-- @author Quenty

local FABRIKElbowConstraint = {}
FABRIKElbowConstraint.ClassName = "FABRIKElbowConstraint"
FABRIKElbowConstraint.__index = FABRIKElbowConstraint

function FABRIKElbowConstraint.new()
	local self = setmetatable({}, FABRIKElbowConstraint)

	return self
end

function FABRIKElbowConstraint:Constrain(lpoint, length)
	local unitlpoint = lpoint.unit
	local px, py, pz = unitlpoint.x, unitlpoint.y, unitlpoint.z

	-- -- disallow lateral movement
	-- if px < 0 then
	-- 	px = px * 0.2
	-- 	if px < 0.1 then
	-- 		px = 0.05
	-- 	end
	-- else
	-- 	px = px * 0.25
	-- end

	-- if py < 0 then
	-- 	py = py * 0.5
	-- elseif py <= 0.25 then
	-- 	py = py + 0.1
	-- end

	return Vector3.new(px, py, pz).unit*length
end

return FABRIKElbowConstraint