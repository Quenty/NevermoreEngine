--- Optimized these functions for speed as well as preserving fidality.
--  In the future, use Roblox's orthogonal angle format.
-- @module CFrameSerializer

local CFrameSerializer = {}

local atan2 = math.atan2
local floor = math.floor
local PI = math.pi
local Angles = CFrame.Angles

local function round(n)
	return floor(n + 0.5)
end

local PRECISION = 10000

function CFrameSerializer.outputRotationAzure(cf)
	local lookVector = cf.lookVector
	local azumith = atan2(-lookVector.X, -lookVector.Z)
	local ybase = (lookVector.X^2 + lookVector.Z^2)^0.5
	local elevation = atan2(lookVector.Y, ybase)

	local withoutRoll = Angles(0, azumith, 0) * Angles(elevation, 0, 0) + cf.p
	local _, _, roll = (withoutRoll:inverse()*cf):toEulerAnglesXYZ()

	-- Atan2 -> in the range [-pi, pi]
	azumith   = round((azumith   /  PI   ) * PRECISION)
	roll      = round((roll      /  PI   ) * PRECISION)
	elevation = round((elevation / (PI/2)) * PRECISION)
	--
	--[[Buffer:WriteSigned(22, azumith)
	Buffer:WriteSigned(21, roll)
	Buffer:WriteSigned(21, elevation)--]]

	local px, py, pz = cf.x, cf.y, cf.z
	px = round(px * 128)
	py = round(py * 128)
	pz = round(pz * 128)
	return {px, py, pz, azumith, roll, elevation}
end

function CFrameSerializer.readPosition(data)
	return Vector3.new(data[1], data[2], data[3])
end

function CFrameSerializer.readRotationAzure(data)
	local azumith = data[4]
	local roll = data[5] --Buffer:ReadSigned(21)
	local elevation = data[6] --Buffer:ReadSigned(21)
	--
	azumith = PI * (azumith/PRECISION)
	roll = PI * (roll/PRECISION)
	elevation = (PI/2) * (elevation/PRECISION)
	--
	--local rot = Angles(0, azumith, 0)
	--rot = rot * Angles(elevation, 0, 0)
	--rot = rot * Angles(0, 0, roll)
	local rot = Angles(0, azumith, 0) * Angles(elevation, 0, roll)
	--
	return rot + Vector3.new(data[1]/128, data[2]/128, data[3]/128) --, azumith, roll, elevation}
end

return CFrameSerializer