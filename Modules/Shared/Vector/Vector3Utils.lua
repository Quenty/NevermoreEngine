---
-- @module Vector3Utils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Math = require("Math")

local Vector3Utils = {}

function Vector3Utils.fromVector2XY(vector2)
	return Vector3.new(vector2.x, vector2.y, 0)
end

function Vector3Utils.fromVector2XZ(vector2)
	return Vector3.new(vector2.x, 0, vector2.y)
end

function Vector3Utils.getAngleRad(offsetUnit, lookVector)
	if offsetUnit.magnitude == 0 then
		return nil
	end

	return math.acos(offsetUnit:Dot(lookVector))
end

function Vector3Utils.round(vector3, amount)
	return Vector3.new(Math.round(vector3.x, amount), Math.round(vector3.y, amount), Math.round(vector3.z, amount))
end

return Vector3Utils