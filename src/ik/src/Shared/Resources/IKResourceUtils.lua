---
-- @module IKResourceUtils

local IKResourceUtils = {}

function IKResourceUtils.createResource(data)
	assert(data.name)
	assert(data.robloxName)
	return data
end

return IKResourceUtils