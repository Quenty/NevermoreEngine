--!strict
--[=[
	Helps get the default or zero value for value types in Roblox
	@class DefaultValueUtils
]=]

local DefaultValueUtils = {}

-- selene: allow(incorrect_standard_library_use)
local DEFAULT_VALUES = {
	["boolean"] = false,
	["BrickColor"] = (BrickColor :: any).new(),
	["CFrame"] = CFrame.new(),
	["Color3"] = Color3.new(),
	["ColorSequence"] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
		ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
	}),
	["ColorSequenceKeypoint"] = ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
	["number"] = 0,
	["PhysicalProperties"] = PhysicalProperties.new(Enum.Material.Plastic), -- Eww
	["NumberRange"] = NumberRange.new(0),
	["NumberSequence"] = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) }),
	["NumberSequenceKeypoint"] = NumberSequenceKeypoint.new(0, 0),
	["Ray"] = (Ray :: any).new(),
	["Rect"] = Rect.new(),
	["Region3"] = (Region3 :: any).new(),
	["Region3int16"] = (Region3int16 :: any).new(),
	["string"] = "",
	["UDim"] = UDim.new(),
	["UDim2"] = UDim2.new(),
	["userdata"] = newproxy(),
	["Vector2"] = Vector2.zero,
	["Vector2int16"] = Vector2int16.new(),
	["Vector3"] = Vector3.zero,
	["Vector3int16"] = Vector3int16.new(),
}

--[=[
	Returns the default value for a given value type. If the type is mutable than
	a new value will ge cosntructed.

	@param typeOfName string
	@return any
]=]
function DefaultValueUtils.getDefaultValueForType(typeOfName: string)
	if DEFAULT_VALUES[typeOfName] ~= nil then
		return DEFAULT_VALUES[typeOfName]
	elseif typeOfName == "table" then
		return {}
	elseif typeOfName == "nil" then
		return nil
	elseif typeOfName == "Random" then
		return Random.new()
	elseif typeOfName == "RaycastParams" then
		return RaycastParams.new()
	elseif typeOfName == "OverlapParams" then
		return OverlapParams.new()
	elseif typeOfName == "Instance" then
		error("Cannot get a defaultValue for an instance")
	else
		error(string.format("Unknown type %q", typeOfName))
	end
end

--[=[
	Converts this value to its default value. If it's a table, it applies it recursively.

	@param value T
	@return T
]=]
function DefaultValueUtils.toDefaultValue(value: any): any
	if type(value) == "table" then
		local result = {}
		for key, item in value do
			result[key] = DefaultValueUtils.toDefaultValue(item)
		end
		return result
	else
		return DefaultValueUtils.getDefaultValueForType(typeof(value))
	end
end

return DefaultValueUtils
