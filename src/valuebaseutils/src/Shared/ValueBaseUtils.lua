--!strict
--[=[
	Provides utilities for working with ValueBase objects, like [IntValue] or [ObjectValue] in Roblox.

	@class ValueBaseUtils
]=]

local ValueBaseUtils = {}

local TYPE_TO_CLASSNAME_LOOKUP = {
	["nil"] = "ObjectValue",
	boolean = "BoolValue",
	number = "NumberValue",
	string = "StringValue",

	BrickColor = "BrickColorValue",
	CFrame = "CFrameValue",
	Color3 = "Color3Value",
	Instance = "ObjectValue",
	Ray = "RayValue",
	Vector3 = "Vector3Value",
}

local VALUE_BASE_TYPE_LOOKUP = {
	BoolValue = "boolean",
	NumberValue = "number",
	IntValue = "number",
	StringValue = "string",
	BrickColorValue = "BrickColor",
	CFrameValue = "CFrame",
	Color3Value = "Color3",
	ObjectValue = "Instance",
	RayValue = "Ray",
	Vector3Value = "Vector3",
}

export type ValueBaseType =
	"BoolValue"
	| "NumberValue"
	| "IntValue"
	| "StringValue"
	| "BrickColorValue"
	| "CFrameValue"
	| "Color3Value"
	| "ObjectValue"
	| "RayValue"
	| "Vector3Value"

--[=[
	Returns true if the value is a ValueBase instance

	@param instance Instance
	@return boolean
]=]
function ValueBaseUtils.isValueBase(instance: Instance): boolean
	return typeof(instance) == "Instance" and instance:IsA("ValueBase")
end

--[=[
	Gets the lua type for the given class name

	@param valueBaseClassName string
	@return string?
]=]
function ValueBaseUtils.getValueBaseType(valueBaseClassName: ValueBaseType): string?
	return VALUE_BASE_TYPE_LOOKUP[valueBaseClassName]
end

--[=[
	Gets class type for the given lua type

	@param luaType string
	@return string?
]=]
function ValueBaseUtils.getClassNameFromType(luaType: string): string?
	return TYPE_TO_CLASSNAME_LOOKUP[luaType]
end

--[=[
	Initializes the value as needed

	@param parent Instance
	@param instanceType string
	@param name string
	@param defaultValue any?
	@return Instance
]=]
function ValueBaseUtils.getOrCreateValue(
	parent: Instance,
	instanceType: ValueBaseType,
	name: string,
	defaultValue
): Instance
	assert(typeof(parent) == "Instance", "Bad argument 'parent'")
	assert(type(instanceType) == "string", "Bad argument 'instanceType'")
	assert(type(name) == "string", "Bad argument 'name'")

	local foundChild = parent:FindFirstChild(name)
	if foundChild then
		if not foundChild:IsA(instanceType) then
			warn(
				string.format(
					"[ValueBaseUtils.getOrCreateValue] - Value of type %q of name %q is of type %q in %s instead",
					instanceType,
					name,
					foundChild.ClassName,
					foundChild:GetFullName()
				)
			)
		end

		return foundChild
	else
		local newChild: any = Instance.new(instanceType)
		newChild.Name = name
		newChild.Value = defaultValue
		newChild.Parent = parent

		return newChild
	end
end

--[=[
	Sets the value for the parent

	@param parent Instance
	@param instanceType string
	@param name string
	@param value any
	@return any
]=]
function ValueBaseUtils.setValue(parent: Instance, instanceType: ValueBaseType, name: string, value: any)
	assert(typeof(parent) == "Instance", "Bad argument 'parent'")
	assert(type(instanceType) == "string", "Bad argument 'instanceType'")
	assert(type(name) == "string", "Bad argument 'name'")

	local foundChild = parent:FindFirstChild(name)
	if foundChild then
		if not foundChild:IsA(instanceType) then
			warn(
				string.format(
					"[ValueBaseUtils.setValue] - Value of type %q of name %q is of type %q in %s instead",
					instanceType,
					name,
					foundChild.ClassName,
					foundChild:GetFullName()
				)
			)
		end

		(foundChild :: any).Value = value
	else
		local newChild: any = Instance.new(instanceType)
		newChild.Name = name
		newChild.Value = value
		newChild.Parent = parent
	end
end

--[=[
	Gets the value in the children

	@param parent Instance
	@param instanceType string
	@param name string
	@param default any?
	@return any
]=]
function ValueBaseUtils.getValue(parent: Instance, instanceType: ValueBaseType, name: string, default: any?)
	assert(typeof(parent) == "Instance", "Bad argument 'parent'")
	assert(type(instanceType) == "string", "Bad argument 'instanceType'")
	assert(type(name) == "string", "Bad argument 'name'")

	local foundChild = parent:FindFirstChild(name)
	if foundChild then
		if foundChild:IsA(instanceType) then
			return (foundChild :: any).Value
		else
			warn(
				string.format(
					"[ValueBaseUtils.getValue] - Value of type %q of name %q is of type %q in %s instead",
					instanceType,
					name,
					foundChild.ClassName,
					foundChild:GetFullName()
				)
			)
			return nil
		end
	else
		return default
	end
end

--[=[
	Gets a getter, setter, and initializer for the instance type and name.

	@param instanceType string
	@param name string
	@return function
	@return function
	@return function
]=]
function ValueBaseUtils.createGetSet(instanceType: ValueBaseType, name: string)
	assert(type(instanceType) == "string", "Bad argument 'instanceType'")
	assert(type(name) == "string", "Bad argument 'name'")

	return function(parent, defaultValue)
		assert(typeof(parent) == "Instance", "Bad argument 'parent'")

		return ValueBaseUtils.getValue(parent, instanceType, name, defaultValue)
	end, function(parent, value)
		assert(typeof(parent) == "Instance", "Bad argument 'parent'")

		return ValueBaseUtils.setValue(parent, instanceType, name, value)
	end, function(parent, defaultValue)
		return ValueBaseUtils.getOrCreateValue(parent, instanceType, name, defaultValue)
	end
end

return ValueBaseUtils
