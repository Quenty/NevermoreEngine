--[=[
	@class JecsUtils
]=]
-- local require = require(script.Parent.loader).load(script)

local JecsUtils = {}

local jecs = assert(script.Parent.Parent:FindFirstChild("Jecs", true), "Jecs not found")
JecsUtils.Jecs = jecs

return JecsUtils
