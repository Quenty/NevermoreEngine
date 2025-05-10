--[=[
	@class IKResourceUtils
]=]

local IKResourceUtils = {}

function IKResourceUtils.createResource(data)
	assert(type(data) == "table", "Bad data")
	assert(data.name, "Bad data.name")
	assert(data.robloxName, "Bad data.robloxName")

	return data
end

return IKResourceUtils
