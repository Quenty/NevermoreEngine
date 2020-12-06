---
-- @module TouchingPartUtils
-- @author Quenty

local EMPTY_FUNCTION = function() end

local TouchingPartUtils = {}

function TouchingPartUtils.getAllTouchingParts(part)
	-- Use the connection hack to gather all touching parts!
	local conn = part.Touched:Connect(EMPTY_FUNCTION)
	local parts = part:GetTouchingParts()

	-- Disconnect connection before we continue
	conn:Disconnect()

	return parts
end

return TouchingPartUtils