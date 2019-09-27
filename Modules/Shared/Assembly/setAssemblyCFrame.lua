--- Gets the full assembly of a part
-- @module setAssemblyCFrame

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local getFullAssembly = require("getFullAssembly")

return function(primaryPart, cframe)
	assert(typeof(primaryPart) == "Instance")
	assert(typeof(cframe) == "CFrame")

	local primaryPartCFrame = primaryPart.CFrame
	local roots = {}
	for _, part in pairs(getFullAssembly(primaryPart)) do
		local rootPart = part:GetRootPart()
		if not roots[rootPart] then
			roots[rootPart] = primaryPartCFrame:toObjectSpace(part.CFrame)
		end
	end

	for root, relCFrame in pairs(roots) do
		root.CFrame = cframe:toWorldSpace(relCFrame)
	end
end
