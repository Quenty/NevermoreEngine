-- qUDim2.lua
-- Utility functions for UDim2's
-- @author Quenty

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoadCustomLibrary = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local qMath             = LoadCustomLibrary("qMath")

local lib = {}

local LerpNumber = qMath.LerpNumber
local UDim2 = UDim2.new

---Interpolates between two UDim2's
local function LerpUDim2(UDim2One, UDim2Two, Alpha)
	return UDim2(
		LerpNumber(UDim2One.X.Scale, UDim2Two.X.Scale, Alpha), 
		LerpNumber(UDim2One.X.Offset, UDim2Two.X.Offset, Alpha),
		LerpNumber(UDim2One.Y.Scale, UDim2Two.Y.Scale, Alpha), 
		LerpNumber(UDim2One.Y.Offset, UDim2Two.Y.Offset, Alpha)
	)
end
lib.LerpUDim2 = LerpUDim2

local function Mult(UDim2One, UDim2Two)
	return UDim2(
		UDim2One.X.Scale * UDim2Two.X.Scale,
		UDim2One.X.Offset * UDim2Two.X.Offset,
		UDim2One.Y.Scale * UDim2Two.Y.Scale,
		UDim2One.Y.Offset * UDim2Two.Y.Offset
	)
end
lib.Mult = Mult

local function Divide(UDim2One, UDim2Two)
	return UDim2(
		UDim2One.X.Scale / UDim2Two.X.Scale,
		UDim2One.X.Offset / UDim2Two.X.Offset,
		UDim2One.Y.Scale / UDim2Two.Y.Scale,
		UDim2One.Y.Offset / UDim2Two.Y.Offset
	)
end
lib.Divide = Divide

return lib
