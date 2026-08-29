--[=[
	@class IrisUtils
]=]
-- local require = require(script.Parent.loader).load(script)

local IrisUtils = {}

local iris = assert(script.Parent.Parent:FindFirstChild("Iris", true), "Iris not found")
IrisUtils.Iris = iris

return IrisUtils