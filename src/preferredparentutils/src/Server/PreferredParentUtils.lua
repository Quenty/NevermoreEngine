--- Handles logic for creating a "preferred" parent container or erroring if
-- it already exists
-- @module PreferredParentUtils

local PreferredParentUtils = {}

function PreferredParentUtils.getPreferredParent(parent, name)
	local found
	for _, item in pairs(parent:GetChildren()) do
		if item.Name == name then
			if not found then
				found = item
			else
				error(("[PreferredParentUtils.getPreferredParent] - Duplicate of %q")
					:format(tostring(item:GetFullName())))
			end
		end
	end

	if found then
		return found
	end

	local newParent = Instance.new("Folder")
	newParent.Name = name
	newParent.Parent = parent

	return newParent
end


return PreferredParentUtils