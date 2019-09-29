--- Gets the full assembly of a part
-- @module setAssemblyCFrame

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local getFullAssembly = require("getFullAssembly")

return function(primaryPart, cframe)
	assert(typeof(primaryPart) == "Instance")
	assert(typeof(cframe) == "CFrame")

	local primaryPartCFrame = primaryPart.CFrame

	local parts = {}
	for _, part in pairs(getFullAssembly(primaryPart)) do
		parts[part] = primaryPartCFrame:toObjectSpace(part.CFrame)
	end

	for part, relCFrame in pairs(parts) do
		part.CFrame = cframe:toWorldSpace(relCFrame)
	end
end
