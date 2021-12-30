--[=[
	Sets a mechanisms cframe
	@class setMechanismCFrame
]=]

local require = require(script.Parent.loader).load(script)

local getMechanismParts = require("getMechanismParts")

return function(originParts, relativeTo, newCFrame)
	assert(typeof(originParts) == "Instance" or typeof(originParts) == "table", "Bad originParts")
	assert(typeof(relativeTo) == "CFrame", "Bad relativeTo")
	assert(typeof(newCFrame) == "CFrame", "Bad newCFrame")

	local target = {}
	for _, part in pairs(getMechanismParts(originParts)) do
		target[part] = relativeTo:toObjectSpace(part.CFrame)
	end

	for part, relCFrame in pairs(target) do
		part.CFrame = newCFrame:toWorldSpace(relCFrame)
	end
end
