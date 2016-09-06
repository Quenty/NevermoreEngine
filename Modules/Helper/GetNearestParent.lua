local function GetNearestParent(Instance, ClassName)
	--- Returns the nearest parent of a certain class, or returns nil
	-- @param Instance The instance to start searching
	-- @param ClassName The class to look for

	local Ancestor = Instance
	repeat
		Ancestor = Ancestor.Parent
		if Ancestor == nil then
			return nil
		end
	until Ancestor:IsA(ClassName)

	return Ancestor
end

return GetNearestParent
