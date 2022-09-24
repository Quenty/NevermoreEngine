--[=[
	@class ReplicatorUtils
]=]

local ReplicatorUtils = {}

function ReplicatorUtils.cloneWithoutChildren(value)
	local original = {}
	for _, item in pairs(value:GetChildren()) do
		if item.Archivable then
			original[item] = true
			item.Archivable = false
		end
	end
	local copy = value:Clone()

	for item, _ in pairs(original) do
		item.Archivable = true
	end

	return copy
end

return ReplicatorUtils