--[=[
	@class DependencyPath
]=]

local DependencyPath = {}
DependencyPath.ClassName = "DependencyPath"
DependencyPath.__index = DependencyPath

function DependencyPath.new()
	local self = setmetatable({}, DependencyPath)

	return self
end

return DependencyPath