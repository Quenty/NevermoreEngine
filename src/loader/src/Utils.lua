--!strict
--[=[
	Utility methods to help with loader functionality.

	@private
	@class Utils
]=]

local Utils = {}

local function errorOnIndex(_, index)
	error(string.format("Bad index %q", tostring(index)), 2)
end

local READ_ONLY_METATABLE = {
	__index = errorOnIndex,
	__newindex = errorOnIndex,
}

function Utils.readonly<T>(_table: T): T
	return setmetatable(_table :: any, READ_ONLY_METATABLE)
end

function Utils.count(_table): number
	local count = 0
	for _, _ in _table do
		count = count + 1
	end
	return count
end

function Utils.getOrCreateValue(parent: Instance, instanceType: string, name: string, defaultValue: any)
	assert(typeof(parent) == "Instance", "Bad argument 'parent'")
	assert(type(instanceType) == "string", "Bad argument 'instanceType'")
	assert(type(name) == "string", "Bad argument 'name'")

	local foundChild = parent:FindFirstChild(name)
	if foundChild then
		if not foundChild:IsA(instanceType) then
			warn(
				string.format(
					"[Utils.getOrCreateValue] - Value of type %q of name %q is of type %q in %s instead",
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

function Utils.getValue(parent: Instance, instanceType: string, name: string, default: any)
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
					"[Utils.getValue] - Value of type %q of name %q is of type %q in %s instead",
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

function Utils.setValue(parent: Instance, instanceType: string, name: string, value: any)
	assert(typeof(parent) == "Instance", "Bad argument 'parent'")
	assert(type(instanceType) == "string", "Bad argument 'instanceType'")
	assert(type(name) == "string", "Bad argument 'name'")

	local foundChild = parent:FindFirstChild(name)
	if foundChild then
		if not foundChild:IsA(instanceType) then
			warn(
				string.format(
					"[Utils.setValue] - Value of type %q of name %q is of type %q in %s instead",
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

function Utils.getOrCreateFolder(parent: Instance, folderName: string): Instance
	local found = parent:FindFirstChild(folderName)
	if found then
		return found
	else
		local folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = parent
		return folder
	end
end

return Utils
