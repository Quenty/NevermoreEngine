---
-- @classmod FABRIKBone

local UNIT_NZ = Vector3.new(0, 0, -1)

local function getRotationBetween(u, v, axis)
	local dot, uxv = u:Dot(v), u:Cross(v)
	if (dot < -0.99999) then return CFrame.fromAxisAngle(axis, math.pi) end
	return CFrame.new(0, 0, 0, uxv.x, uxv.y, uxv.z, 1 + dot)
end

local FABRIKBone = {}
FABRIKBone.ClassName = "FABRIKBone"
FABRIKBone.__index = FABRIKBone

function FABRIKBone.new(vtxA, vtxB, cf, constraint)
	local self = setmetatable({}, FABRIKBone)

	self.VertexA = vtxA
	self.VertexB = vtxB
	self.Length = (vtxA.Point - vtxB.Point).Magnitude
	self.CFrame = cf
	self.AlignedCFrame = cf
	self.Constraint = constraint

	return self
end

function FABRIKBone:GetCFrame()
	return (self.CFrame - self.CFrame.p) + self.VertexA.Point
end

function FABRIKBone:GetAlignedCFrame()
	local lastCF = self.CFrame
	local newPoint = self.VertexB.Point
	local rVector = lastCF:VectorToObjectSpace(newPoint - self.VertexA.Point)
	local alignedCFrame = lastCF * getRotationBetween(UNIT_NZ, rVector.Unit, lastCF.RightVector)

	return alignedCFrame
end

function FABRIKBone:GetAlignedOffsetCFrame(offset)
	local lastCF = self.CFrame
	local newPoint = self.VertexB.Point + offset
	local rVector = lastCF:VectorToObjectSpace(newPoint - self.VertexA.Point)
	local alignedCFrame = lastCF * getRotationBetween(UNIT_NZ, rVector.Unit, lastCF.RightVector)

	return alignedCFrame
end


return FABRIKBone