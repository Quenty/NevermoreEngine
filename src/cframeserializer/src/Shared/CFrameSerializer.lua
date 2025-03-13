--!strict
--[=[
	Optimized these functions for speed as well as preserving fidality.
	In the future, use Roblox's orthogonal angle format.

	@class CFrameSerializer
]=]

local HttpService = game:GetService("HttpService")

local require = require(script.Parent.loader).load(script)

local Math = require("Math")

local CFrameSerializer = {}

local PRECISION = 10000
local MULTIPLIER = 128

export type SerializedCFrame = { number }

--[=[
	Outputs the rotation
	@param cf CFrame
	@return { number, number, number, number, number, number }
]=]
function CFrameSerializer.outputRotationAzure(cf: CFrame): SerializedCFrame
	local lookVector = cf.LookVector
	local azumith = math.atan2(-lookVector.X, -lookVector.Z)
	local ybase = (lookVector.X ^ 2 + lookVector.Z ^ 2) ^ 0.5
	local elevation = math.atan2(lookVector.Y, ybase)

	local withoutRoll = CFrame.Angles(0, azumith, 0) * CFrame.Angles(elevation, 0, 0) + cf.Position
	local _, _, roll = (withoutRoll:Inverse() * cf):ToEulerAnglesXYZ()

	-- Atan2 -> in the range [-pi, pi]
	azumith = Math.round((azumith / math.pi) * PRECISION)
	roll = Math.round((roll / math.pi) * PRECISION)
	elevation = Math.round((elevation / (math.pi / 2)) * PRECISION)

	-- Buffer:WriteSigned(22, azumith)
	-- Buffer:WriteSigned(21, roll)
	-- Buffer:WriteSigned(21, elevation)

	local px, py, pz = cf.X, cf.Y, cf.Z
	px = Math.round(px * MULTIPLIER)
	py = Math.round(py * MULTIPLIER)
	pz = Math.round(pz * MULTIPLIER)
	return { px, py, pz, azumith, roll, elevation }
end

--[=[
	Encodes a CFrame into JSON for serialization in attributes.

	@param cf CFrame
	@return string
]=]
function CFrameSerializer.toJSONString(cf: CFrame): string
	return HttpService:JSONEncode(CFrameSerializer.outputRotationAzure(cf))
end

--[=[
	Returnst true if it's a table encoded cframe

	@param data any
	@return boolean
]=]
function CFrameSerializer.isRotationAzure(data: any): boolean
	return type(data) == "table"
		and type(data[1]) == "number"
		and type(data[2]) == "number"
		and type(data[3]) == "number"
		and type(data[4]) == "number"
		and type(data[5]) == "number"
		and type(data[6]) == "number"
end

--[=[
	Decodes a CFrame from JSON. For serialization in attributes.

	@param str string
	@return CFrame
]=]
function CFrameSerializer.fromJSONString(str: string): CFrame?
	local decoded = HttpService:JSONDecode(str)
	if CFrameSerializer.isRotationAzure(decoded) then
		return CFrameSerializer.readRotationAzure(decoded)
	else
		return nil
	end
end

--[=[
	Returns the position
	@param data { number, number, number, number, number, number }
	@return Vector3
]=]
function CFrameSerializer.readPosition(data: SerializedCFrame): Vector3
	return Vector3.new(data[1] / MULTIPLIER, data[2] / MULTIPLIER, data[3] / MULTIPLIER)
end

--[=[
	Returns the CFrame

	@param data { number, number, number, number, number, number }
	@return CFrame
]=]
function CFrameSerializer.readRotationAzure(data: SerializedCFrame): CFrame
	local azumith = data[4]
	local roll = data[5] -- Buffer:ReadSigned(21)
	local elevation = data[6] -- Buffer:ReadSigned(21)

	azumith = math.pi * (azumith/PRECISION)
	roll = math.pi * (roll/PRECISION)
	elevation = (math.pi/2) * (elevation/PRECISION)

	local cframe = CFrame.Angles(0, azumith, 0) * CFrame.Angles(elevation, 0, roll)
	return cframe + Vector3.new(data[1]/MULTIPLIER, data[2]/MULTIPLIER, data[3]/MULTIPLIER) --, azumith, roll, elevation}
end

return CFrameSerializer