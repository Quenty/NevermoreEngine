---
-- @module Set
-- @author Quenty

local Set = {}

function Set.fromTableValue(tab)
	local set = {}

	for _, value in pairs(tab) do
		set[value] = true
	end

	return set
end

return Set