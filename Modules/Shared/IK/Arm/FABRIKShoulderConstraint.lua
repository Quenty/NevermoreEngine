---
-- @classmod FABRIKShoulderConstraint
-- @author Quenty

local FABRIKShoulderConstraint = {}
FABRIKShoulderConstraint.ClassName = "FABRIKShoulderConstraint"
FABRIKShoulderConstraint.__index = FABRIKShoulderConstraint

function FABRIKShoulderConstraint.new()
	local self = setmetatable({}, FABRIKShoulderConstraint)

	return self
end

function FABRIKShoulderConstraint:Constrain(lpoint, length, targetNotReachable)
	local unitlpoint = lpoint.unit
	local px, py, pz = unitlpoint.x, unitlpoint.y, unitlpoint.z

	-- --
	-- if py > 0.2 then
	-- 	py = py * 0.1
	-- elseif py > 0 then
	-- 	py = -0.1
	-- end

	-- -- prefer downwards facing elbow
	-- if pz > 0.1 then
	-- 	pz = pz * 0.5
	-- elseif pz > 0 then
	-- 	pz = -0.1
	-- end

	-- prefer elbow facing out
	if px > 0 and (not targetNotReachable) then
		print("px > 0", px)
		px = -0.1*px
	elseif px < -0.2 then
		-- drive x axis to zero
		px = px + 0.05
	end


	if py > -0.2 then
		py = py - 0.05
		pz = pz + 0.05
	end

	-- print(px, py, pz)
	return Vector3.new(px, py, pz).unit*length
end

return FABRIKShoulderConstraint