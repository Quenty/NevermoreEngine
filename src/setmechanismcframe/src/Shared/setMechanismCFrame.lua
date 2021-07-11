--- Sets a mechanisms cframe
-- @module setMechanismCFrame

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local getMechanismParts = require("getMechanismParts")

return function(originParts, relativeTo, newCFrame)
	assert(typeof(originParts) == "Instance" or typeof(originParts) == "table")
	assert(typeof(relativeTo) == "CFrame")
	assert(typeof(newCFrame) == "CFrame")

	local target = {}
	for _, part in pairs(getMechanismParts(originParts)) do
		target[part] = relativeTo:toObjectSpace(part.CFrame)
	end

	for part, relCFrame in pairs(target) do
		part.CFrame = newCFrame:toWorldSpace(relCFrame)
	end
end
