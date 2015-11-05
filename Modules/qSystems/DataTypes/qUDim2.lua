local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qMath             = LoadCustomLibrary("qMath")

--- Utility functions for UDim2's
-- @module UDim2
-- @author Quenty

local lib = {}

local LerpNumber = qMath.LerpNumber

---Interpolates between two UDim2's
local function LerpUDim2(UDim2One, UDim2Two, Alpha)
	return UDim2.new(
		LerpNumber(UDim2One.X.Scale, UDim2Two.X.Scale, Alpha), 
		LerpNumber(UDim2One.X.Offset, UDim2Two.X.Offset, Alpha),
		LerpNumber(UDim2One.Y.Scale, UDim2Two.Y.Scale, Alpha), 
		LerpNumber(UDim2One.Y.Offset, UDim2Two.Y.Offset, Alpha)
	)
end
lib.LerpUDim2 = LerpUDim2

return lib
