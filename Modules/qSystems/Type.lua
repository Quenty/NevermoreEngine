-- @author Mark Otaris (ColorfulBody, JulienDethurens) and Quenty
-- Last modified December 28th, 2013

-- This library contains a collection of clever hacks.
-- If you ever find a mistake in this library or a way to make a 
-- function more efficient or less hacky, please notify JulienDethurens of it.

-- As far as is known, the functions in this library are foolproof. 
-- It cannot be fooled by a fake value that looks like a real one. 
-- If it says a value is a CFrame, then it _IS_ a CFrame, period.


local lib = {}

local function set(object, property, value)
	-- Sets the 'property' property of 'object' to 'value'.
	-- This is used with pcall to avoid creating functions needlessly.
	object[property] = value
end

function lib.isAnInstance(value)
	-- Returns whether 'value' is an Instance value.
	local _, result = pcall(Game.IsA, value, 'Instance')
	return result == true
end

function lib.isALibrary(value)
	-- Returns whether 'value' is a RbxLibrary.
	-- Finds its result by checking whether the value's GetApi function (if it has one) can be dumped (and therefore is a non-Lua function).
	if pcall(function() assert(type(value.GetApi) == 'function') end) then -- Check if the value has a GetApi function.
		local success, result = pcall(string.dump, value.GetApi) -- Try to dump the GetApi function.
		return result == "unable to dump given function" -- Return whether the GetApi function could be dumped.
	end
	return false
end

function lib.isAnEnum(value)
	-- Returns whether the value is an enum.
	return pcall(Enum.Material.GetEnumItems, value) == true
end

function lib.coerceIntoEnum(value, enum)
	-- Coerces a value into an enum item, if possible, throws an error otherwise.
	if lib.isAnEnum(enum) then
		for _, enum_item in next, enum:GetEnumItems() do
			if value == enum_item or value == enum_item.Name or value == enum_item.Value then return enum_item end
		end
	else
		error("The 'enum' argument must be an enum.", 2)
	end
	error("The value cannot be coerced into a enum item of the specified type.", 2)
end

function lib.isOfEnumType(value, enum)
	-- Returns whether 'value' is coercible into an enum item of the type 'enum'.
	if lib.isAnEnum(enum) then
		return pcall(lib.coerceIntoEnum, value, enum) == true
	else
		error("The 'enum' argument must be an enum.", 2)
	end
end

local Color3Value = Instance.new('Color3Value')
function lib.isAColor3(value)
	-- Returns whether 'value' is a Color3 value.
	return pcall(set, Color3Value, 'Value', value) == true
end

local CFrameValue = Instance.new('CFrameValue')
function lib.isACoordinateFrame(value)
	-- Returns whether 'value' is a CFrame value.
	return pcall(set, CFrameValue, 'Value', value) == true
end

local BrickColor3Value = Instance.new('BrickColorValue')
function lib.isABrickColor(value)
	-- Returns whether 'value' is a BrickColor value.
	return pcall(set, BrickColor3Value, 'Value', value) == true
end

local RayValue = Instance.new('RayValue')
function lib.isARay(value)
	-- Returns whether 'value' is a Ray value.
	return pcall(set, RayValue, 'Value', value) == true
end

local Vector3Value = Instance.new('Vector3Value')
function lib.isAVector3(value)
	-- Returns whether 'value' is a Vector3 value.
	return pcall(set, Vector3Value, 'Value', value) == true
end

function lib.isAVector2(value)
	-- Returns whether 'value' is a Vector2 value.
	return pcall(function() return Vector2.new() + value end) == true
end

local FrameValue = Instance.new('Frame')
function lib.isAUdim2(value)
	-- Returns whether 'value' is a UDim2 value.
	return pcall(set, FrameValue, 'Position', value) == true
end

function lib.isAUDim(value)
	-- Returns whether 'value' is a UDim value.
	return pcall(function() return UDim.new() + value end) == true
end

local ArcHandleValue = Instance.new('ArcHandles')
function lib.isAAxis(value)
	-- Returns whether 'value' is an Axes value.
	return pcall(set, ArcHandleValue, 'Axes', value) == true
end

local FaceValue = Instance.new('Handles')
function lib.isAFace(value)
	-- Returns whether 'value' is a Faces value.
	return pcall(set, FaceValue, 'Faces', value) == true
end

function lib.isASignal(value)
	-- Returns whether 'value' is a RBXScriptSignal.
	local success, connection = pcall(function() return Game.AllowedGearTypeChanged.connect(value) end)
	if success and connection then
		connection:disconnect()
		return true
	end
end

	
function lib.getType(value)
	-- Returns the most specific obtainable type of a value it can.
	-- Useful for error messages or anything that is meant to be shown to the user.

	local valueType = type(value)

	if valueType == 'userdata' then
		if lib.isAnInstance(value) then return value.ClassName
		elseif lib.isAColor3(value) then return 'Color3'
		elseif lib.isACoordinateFrame(value) then return 'CFrame'
		elseif lib.isABrickColor(value) then return 'BrickColor'
		elseif lib.isAUDim2(value) then return 'UDim2'
		elseif lib.isAUDim(value) then return 'UDim'
		elseif lib.isAVector3(value) then return 'Vector3'
		elseif lib.isAVector2(value) then return 'Vector2'
		elseif lib.isARay(value) then return 'Ray'
		elseif lib.isAnEnum(value) then return 'Enum'
		elseif lib.isASignal(value) then return 'RBXScriptSignal'
		elseif lib.isALibrary(value) then return 'RbxLibrary'
		elseif lib.isAAxis(value) then return 'Axes'
		elseif lib.isAFace(value) then return 'Faces'
		end
	else
		return valueType;
	end
end

function lib.isAnInt(value)
	-- Returns whether 'value' is an interger or not
	return type(value) == "number" and value % 1 == 1;
end


function lib.isPositiveInt(number)
	-- Returns whether 'value' is a positive interger or not.  
	-- Useful for money transactions, and is used in the method isAnArray ( )
	return type(value) == "number" and number > 0 and math.floor(number) == number
end


function lib.isAnArray(value)
	-- Returns if 'value' is an array or not

	if type(value) == "table" then
		local maxNumber = 0;
		local totalCount = 0;

		for index, _ in next, value do
			if lib.isPositiveInt(index) then
				maxNumber = math.max(maxNumber, index)
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

return lib