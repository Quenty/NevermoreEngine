---
-- @classmod FABRIKChain

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local FABRIKVertex = require("FABRIKVertex")
local FABRIKBone = require("FABRIKBone")

local UNIT_NZ = Vector3.new(0, 0, -1)
local BREAK_COUNT = 20
local TOLERANCE = 0.02

--

local FABRIKChain = {}
FABRIKChain.__index = FABRIKChain

--

local function lerp(a, b, t)
	return (1-t)*a + t*b
end

local function getRotationBetween(u, v, axis)
	local dot, uxv = u:Dot(v), u:Cross(v)
	if (dot < -0.99999) then return CFrame.fromAxisAngle(axis, math.pi) end
	return CFrame.new(0, 0, 0, uxv.x, uxv.y, uxv.z, 1 + dot)
end

--

function FABRIKChain.new(bones)
	local self = setmetatable({}, FABRIKChain)

	local length = 0
	for i = 1, #bones do
		length = length + bones[i].Length
	end

	self._originCF = bones[1].CFrame
	self._bones = bones
	self._target = bones[#bones].VertexB.Point
	self._length = length

	return self
end

function FABRIKChain.fromPointsConstraints(originCF, points, constraints, offsets)
	local vertices = {}

	for i = 1, #points do
		vertices[i] = FABRIKVertex.new(points[i])
	end

	local bones = {}
	local lastCF = originCF

	for i = 1, #vertices - 1 do
		local cur = vertices[i]
		local nxt = vertices[i+1]

		bones[i] = FABRIKBone.new(cur, nxt, lastCF, constraints[i], offsets[i])

		local vector = nxt.Point - cur.Point
		local rVector = lastCF:VectorToObjectSpace(vector)
		lastCF = lastCF * getRotationBetween(UNIT_NZ, rVector.Unit, lastCF.RightVector)
	end

	return FABRIKChain.new(bones)
end

--

function FABRIKChain:SetTarget(target)
	self._target = target
end

function FABRIKChain:GetBones()
	return self._bones
end

function FABRIKChain:GetPoints()
	local points = {}
	local bones = self._bones
	for i = 1, #bones do
		table.insert(points, bones[i].VertexA.Point)
	end
	table.insert(points, bones[#bones].VertexB.Point)
	return points
end

function FABRIKChain:IterBone(bone, vtxA, vtxB, target, lastCF, targetNotReachable)
	local realLength = (target - vtxA.Point).Magnitude
	local lerpPercent = bone.Length / realLength

	local newPoint = lerp(vtxA.Point, target, lerpPercent)

	if bone.VectorOffset then
		local relOffset = newPoint - vtxA.Point
		local mag = relOffset.magnitude
		relOffset = relOffset + (lastCF or bone:GetCFrame()):vectorToWorldSpace(bone.VectorOffset)
		relOffset = relOffset.unit * mag
		newPoint = vtxA.Point + relOffset
	end

	if (lastCF) then
		bone.CFrame = lastCF

		if (bone.Constraint) then
			local boneCF = bone:GetCFrame()
			local lPoint = bone.Constraint:Constrain(boneCF:PointToObjectSpace(newPoint), bone.Length, targetNotReachable)
			newPoint = boneCF * lPoint
		end

		local rVector = lastCF:VectorToObjectSpace(newPoint - vtxA.Point)
		lastCF = lastCF * getRotationBetween(UNIT_NZ, rVector.Unit, lastCF.RightVector)
	end

	vtxB.Point = newPoint

	return lastCF
end

function FABRIKChain:Forward()
	local bones = self._bones
	local lastCF = self._originCF

	bones[1].VertexA.Point = lastCF.p
	for i = 1, #bones do
		local bone = bones[i]
		lastCF = self:IterBone(bone, bone.VertexA, bone.VertexB, bone.VertexB.Point, lastCF)
	end
end

function FABRIKChain:Backward()
	local bones = self._bones

	bones[#bones].VertexB.Point = self._target
	for i = #bones, 1, -1 do
		local bone = bones[i]
		self:IterBone(bone, bone.VertexB, bone.VertexA, bone.VertexA.Point, nil)
	end
end


function FABRIKChain:Solve()
	local bones = self._bones
	local target = self._target

	local distance = (self._originCF.p - target).Magnitude
	if (distance >= self._length) then
		local lastCF = bones[1].CFrame
		for i = 1, #bones do
			local bone = bones[i]
			lastCF = self:IterBone(bone, bone.VertexA, bone.VertexB, target, lastCF, true)
		end
	else
		local break_count = 0
		local nBones = #bones
		local difference = (bones[nBones].VertexB.Point - target).Magnitude

		while (difference > TOLERANCE) do
			self:Backward()
			self:Forward()

			difference = (bones[nBones].VertexB.Point - target).Magnitude

			break_count = break_count + 1
			if (break_count >= BREAK_COUNT) then
				break
			end
		end
	end
end

--

return FABRIKChain