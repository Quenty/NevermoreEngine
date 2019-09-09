--- Gets the full assembly of a part
-- @module setAssemblyCFrame

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local getFullAssembly = require("getFullAssembly")

return function(primaryPart, cframe)
	assert(typeof(primaryPart) == "Instance")
	assert(typeof(cframe) == "CFrame")

	local primaryPartCFrame = primaryPart.CFrame
	for _, part in pairs(getFullAssembly(primaryPart)) do
		part.CFrame = cframe:toWorldSpace(primaryPartCFrame:toObjectSpace(part.CFrame))
	end

	primaryPart.CFrame = cframe
end
