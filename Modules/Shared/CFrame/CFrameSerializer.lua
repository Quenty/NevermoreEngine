--- Optimized these functions for speed as well as preserving fidality.
--  In the future, use Roblox's orthogonal angle format.
-- @module CFrameSerializer

local lib = {}

local atan2 = math.atan2
local floor = math.floor
local PI = math.pi
local Angles = CFrame.Angles

local function round(n)
	return floor(n + 0.5)
end

local bitSize22 = (2^21-1)
local bitSize21 = (2^20-1)

function lib.OutputRotationAzure(cf)
	local lookVector = cf.lookVector
	local azumith = atan2(-lookVector.X, -lookVector.Z)
	local ybase = (lookVector.X^2 + lookVector.Z^2)^0.5
	local elevation = atan2(lookVector.Y, ybase)

	local withoutRoll = Angles(0, azumith, 0) * Angles(elevation, 0, 0) + cf.p
	local _, _, roll = (withoutRoll:inverse()*cf):toEulerAnglesXYZ()

	-- Atan2 -> in the range [-pi, pi]
	azumith   = round((azumith   /  PI   ) * bitSize22)
	roll      = round((roll      /  PI   ) * bitSize21)
	elevation = round((elevation / (PI/2)) * bitSize21)
	--
	--[[Buffer:WriteSigned(22, azumith)
	Buffer:WriteSigned(21, roll)
	Buffer:WriteSigned(21, elevation)--]]

	local px, py, pz = cf.x, cf.y, cf.z
	px = round(px * 128) / 128
	py = round(py * 128) / 128
	pz = round(pz * 128) / 128
	return {px, py, pz, azumith, roll, elevation}
end

function lib.ReadRotationAzure(data)
	local azumith = data[4]
	local roll = data[5] --Buffer:ReadSigned(21)
	local elevation = data[6] --Buffer:ReadSigned(21)
	--
	azumith = PI * (azumith/bitSize22)
	roll = PI * (roll/bitSize21)
	elevation = (PI/2) * (elevation/bitSize21)
	--
	--local rot = Angles(0, azumith, 0)
	--rot = rot * Angles(elevation, 0, 0)
	--rot = rot * Angles(0, 0, roll)
	local rot = Angles(0, azumith, 0) * Angles(elevation, 0, roll)
	--
	return rot + Vector3.new(data[1], data[2], data[3]) --, azumith, roll, elevation}
end

return lib