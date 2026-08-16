--!strict
--[=[
	@class ImmediateHookSpringUtils
]=]
local ImmediateHookSpringUtils = {}

function ImmediateHookSpringUtils.internalValue(value: any): any
	if typeof(value) == "Color3" then
		return Vector3.new(value.R, value.G, value.B)
	end
	return value
end

function ImmediateHookSpringUtils.externalValue(internal: any, asColor3: boolean): any
	if asColor3 and typeof(internal) == "Vector3" then
		return Color3.new(math.clamp(internal.X, 0, 1), math.clamp(internal.Y, 0, 1), math.clamp(internal.Z, 0, 1))
	end
	return internal
end

function ImmediateHookSpringUtils.usesColor3(goal: any?, value: any?): boolean
	if goal ~= nil then
		return typeof(goal) == "Color3"
	end
	if value ~= nil then
		return typeof(value) == "Color3"
	end
	return false
end

return ImmediateHookSpringUtils
