--!strict
--[=[
	Sets a mechanisms cframe
	@class setMechanismCFrame
]=]

local require = require(script.Parent.loader).load(script)

local getMechanismParts = require("getMechanismParts")

return function(originParts: Instance | { BasePart }, relativeTo: CFrame, newCFrame: CFrame)
	assert(typeof(originParts) == "Instance" or typeof(originParts) == "table", "Bad originParts")
	assert(typeof(relativeTo) == "CFrame", "Bad relativeTo")
	assert(typeof(newCFrame) == "CFrame", "Bad newCFrame")

	local target = {}
	for _, part in getMechanismParts(originParts) do
		target[part] = relativeTo:ToObjectSpace(part.CFrame)
	end

	for part, relCFrame in target do
		part.CFrame = newCFrame:ToWorldSpace(relCFrame)
	end
end
