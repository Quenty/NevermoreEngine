---
-- @classmod FABRIKBone

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
	return (self.AlignedCFrame - self.AlignedCFrame.p) + self.VertexA.Point
end

return FABRIKBone