-- @author Mark Otaris (ColorfulBody, JulienDethurens) and Quenty
-- @Editor Narrev
-- Last updated December 28th, 2013

-- This library contains a collection of clever hacks.
-- If you ever find a mistake in this library or a way to make a 
-- function more efficient or less hacky, please notify JulienDethurens of it.

-- As far as is known, the functions in this library are foolproof. 
-- It cannot be fooled by a fake value that looks like a real one. 
-- If it says a value is a CFrame, then it _IS_ a CFrame, period.

-- Localize Creation Functions
local UDim		= UDim.new
local Vector2	= Vector2.new
local Instance	= Instance.new

-- Localize math functions
local floor	= math.floor
local max	= math.max

local match	= string.match

-- Create Values
local RayValue = Instance("RayValue")
local FaceValue = Instance("Handles")
local FrameValue = Instance("Frame")
local Color3Value = Instance("Color3Value")
local CFrameValue = Instance("CFrameValue")
local Vector3Value = Instance("Vector3Value")
local ArcHandleValue = Instance("ArcHandles")
local BrickColor3Value = Instance("BrickColorValue")

-- Helper functions
local function set(object, property, value)
	-- Sets the 'property' property of 'object' to 'value'.
	-- This is used with pcall to avoid creating functions needlessly.
	object[property] = value
end

-- Identifier Functions
local function isARay(value) return pcall(set, RayValue, "Value", value) == true end
local function isAFace(value) return pcall(set, FaceValue, "Faces", value) == true end
local function isAnAxis(value) return pcall(set, ArcHandleValue, "Axes", value) == true end
local function isAnInt(value) return type(value) == "number" and value % 1 == 0 end
local function isAnEnum(value) return match(tostring(value), "(%a-)%.") == "Enum" end
local function isAColor3(value) return pcall(set, Color3Value, "Value", value) == true end
local function isAUDim2(value) return pcall(set, FrameValue, "Position", value) == true end
local function isAVector3(value) return pcall(set, Vector3Value, "Value", value) == true end
local function isAUDim(value) return pcall(function() return UDim() + value end) == true end
local function isAVector2(value) return pcall(function() return Vector2() + value end) == true end
local function isACoordinateFrame(value) return pcall(set, CFrameValue, "Value", value) == true end
local function isABrickColor(value)	return pcall(set, BrickColor3Value, "Value", value) == true end
local function isPositiveInt(number) return type(number) == "number" and number > 0 and floor(number) == number end

local function coerceIntoEnum(value, enum)
	-- Coerces a value into an enum item, if possible, throws an error otherwise.
	if isAnEnum(enum) then
		local enumTable = enum:GetEnumItems()
		for i = 1, #enumTable do
			local enum_item = enumTable[i]
			if value == enum_item or value == enum_item.Name or value == enum_item.Value then return enum_item end
		end
	else
		error("The 'enum' argument must be an enum.", 2)
	end
	error("The value cannot be coerced into a enum item of the specified type.", 2)
end

local function isAnInstance(value)
	-- Returns whether 'value' is an Instance value.
	local _, result = pcall(game.IsA, value, "Instance")
	return result == true
end

local function isALibrary(value)
	-- Returns whether 'value' is a RbxLibrary.
	-- Finds its result by checking whether the value's GetApi function (if it has one) can be dumped (and therefore is a non-Lua function).
	if pcall(function() assert(type(value.GetApi) == "function") end) then -- Check if the value has a GetApi function.
		local success, result = pcall(string.dump, value.GetApi) -- Try to dump the GetApi function.
		return result == "unable to dump given function" -- Return whether the GetApi function could be dumped.
	end
	return false
end

local function isASignal(value)
	-- Returns whether 'value' is a RBXScriptSignal.
	local success, connection = pcall(function() return game.AllowedGearTypeChanged.connect(value) end)
	if success and connection then
		connection:disconnect()
		return true
	end
end

local function isAnArray(value)
	-- Returns if 'value' is an array or not

	if type(value) == "table" then
		local maxNumber = 0;
		local totalCount = 0;

		for index, _ in next, value do
			if isPositiveInt(index) then
				maxNumber = max(maxNumber, index)
				totalCount = totalCount + 1
			else
				return false;
			end
		end

		return maxNumber == totalCount;
	else
		return false;
	end
end

-- Wrapper functions
local function isOfEnumType(value, enum)
	-- Returns whether 'value' is coercible into an enum item of the type 'enum'.
	if isAnEnum(enum) then
		return pcall(coerceIntoEnum, value, enum) == true
	else
		error("The 'enum' argument must be an enum.", 2)
	end
end

local function getType(value)
	-- Returns the most specific obtainable type of a value it can.
	-- Useful for error messages or anything that is meant to be shown to the user.

	if isAnArray(value) then return "array"
	elseif isAnInt(value) then return "int"
	end

	if type(value) == "userdata" then
		if isACoordinateFrame(value) then return "CFrame"
		elseif isABrickColor(value) then return "BrickColor"
		elseif isAnInstance(value) then return value.ClassName
		elseif isALibrary(value) then return "RbxLibrary"
		elseif isAVector3(value) then return "Vector3"
		elseif isAVector2(value) then return "Vector2"
		elseif isASignal(value) then return "RBXScriptSignal"
		elseif isAColor3(value) then return "Color3"
		elseif isAUDim2(value) then return "UDim2"
		elseif isAnEnum(value) then return "Enum"
		elseif isAnAxis(value) then return "Axes"
		elseif isAFace(value) then return "Faces"
		elseif isAUDim(value) then return "UDim"
		elseif isARay(value) then return "Ray"
		end
	end
	return type(value)
end

return setmetatable({
	-- This is a list of functions the user can access
	isARay = isARay;
	isAFace = isAFace;
	isAUDim = isAUDim;
	isAnInt = isAnInt;
	isAUDim2 = isAUDim2;
	isAnEnum = isAnEnum;
	isAnAxis = isAnAxis;
	isAColor3 = isAColor3;
	isASignal = isASignal;
	isAnArray = isAnArray;
	isAVector3 = isAVector3;
	isAVector2 = isAVector2;
	isALibrary = isALibrary;
	isAnInstance = isAnInstance;
	isPositiveInt = isPositiveInt;
	isABrickColor = isABrickColor;
	isACoordinateFrame = isACoordinateFrame;
	
	getType = getType;
	isOfEnumType = isOfEnumType;
	coerceIntoEnum = coerceIntoEnum;
	
}, {__call = function(_, value)
	return getType(value)
end})
