---
-- @module ValueBaseUtils
-- @author Quenty

local ValueBaseUtils = {}

function ValueBaseUtils.getOrCreateValue(parent, instanceType, name, defaultValue)
	assert(typeof(parent) == "Instance", "Bad argument 'parent'")
	assert(type(instanceType) == "string", "Bad argument 'instanceType'")
	assert(type(name) == "string", "Bad argument 'name'")

	local foundChild = parent:FindFirstChild(name)
	if foundChild then
		if not foundChild:IsA(instanceType) then
			warn(("[ValueBaseUtils.getOrCreateValue] - Value of type %q of name %q is of type %q in %s instead")
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

function ValueBaseUtils.setValue(parent, instanceType, name, value)
	assert(typeof(parent) == "Instance", "Bad argument 'parent'")
	assert(type(instanceType) == "string", "Bad argument 'instanceType'")
	assert(type(name) == "string", "Bad argument 'name'")

	local foundChild = parent:FindFirstChild(name)
	if foundChild then
		if not foundChild:IsA(instanceType) then
			warn(("[ValueBaseUtils.setValue] - Value of type %q of name %q is of type %q in %s instead")
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

function ValueBaseUtils.getValue(parent, instanceType, name, default)
	assert(typeof(parent) == "Instance", "Bad argument 'parent'")
	assert(type(instanceType) == "string", "Bad argument 'instanceType'")
	assert(type(name) == "string", "Bad argument 'name'")

	local foundChild = parent:FindFirstChild(name)
	if foundChild then
		if foundChild:IsA(instanceType) then
			return foundChild.Value
		else
			warn(("[ValueBaseUtils.getValue] - Value of type %q of name %q is of type %q in %s instead")
				:format(instanceType, name, foundChild.ClassName, foundChild:GetFullName()))
			return nil
		end
	else
		return default
	end
end

return ValueBaseUtils