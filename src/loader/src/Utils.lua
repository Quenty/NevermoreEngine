--[=[
	@private
	@class Utils
]=]

local Utils = {}

local function errorOnIndex(_, index)
	error(("Bad index %q"):format(tostring(index)), 2)
end

local READ_ONLY_METATABLE = {
	__index = errorOnIndex;
	__newindex = errorOnIndex;
}

function Utils.readonly(_table)
	return setmetatable(_table, READ_ONLY_METATABLE)
end

function Utils.count(_table)
	local count = 0
	for _, _ in pairs(_table) do
		count = count + 1
	end
	return count
end

function Utils.getOrCreateValue(parent, instanceType, name, defaultValue)
	assert(typeof(parent) == "Instance", "Bad argument 'parent'")
	assert(type(instanceType) == "string", "Bad argument 'instanceType'")
	assert(type(name) == "string", "Bad argument 'name'")

	local foundChild = parent:FindFirstChild(name)
	if foundChild then
		if not foundChild:IsA(instanceType) then
			warn(("[Utils.getOrCreateValue] - Value of type %q of name %q is of type %q in %s instead")
				:format(instanceType, name, foundChild.ClassName, foundChild:GetFullName()))
		end

		return foundChild
	else
		local newChild = Instance.new(instanceType)
		newChild.Name = name
		newChild.Value = defaultValue
		newChild.Parent = parent

		return newChild
	end
end

function Utils.getValue(parent, instanceType, name, default)
	assert(typeof(parent) == "Instance", "Bad argument 'parent'")
	assert(type(instanceType) == "string", "Bad argument 'instanceType'")
	assert(type(name) == "string", "Bad argument 'name'")

	local foundChild = parent:FindFirstChild(name)
	if foundChild then
		if foundChild:IsA(instanceType) then
			return foundChild.Value
		else
			warn(("[Utils.getValue] - Value of type %q of name %q is of type %q in %s instead")
				:format(instanceType, name, foundChild.ClassName, foundChild:GetFullName()))
			return nil
		end
	else
		return default
	end
end

function Utils.setValue(parent, instanceType, name, value)
	assert(typeof(parent) == "Instance", "Bad argument 'parent'")
	assert(type(instanceType) == "string", "Bad argument 'instanceType'")
	assert(type(name) == "string", "Bad argument 'name'")

	local foundChild = parent:FindFirstChild(name)
	if foundChild then
		if not foundChild:IsA(instanceType) then
			warn(("[Utils.setValue] - Value of type %q of name %q is of type %q in %s instead")
				:format(instanceType, name, foundChild.ClassName, foundChild:GetFullName()))
		end

		foundChild.Value = value
	else
		local newChild = Instance.new(instanceType)
		newChild.Name = name
		newChild.Value = value
		newChild.Parent = parent
	end
end


function Utils.getOrCreateFolder(parent, folderName)
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
