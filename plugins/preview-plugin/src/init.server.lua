--[=[
	Plugin entry point
]=]

local modules = script:WaitForChild("modules")
local loader = modules:FindFirstChild("LoaderUtils", true).Parent

local require = require(loader).bootstrapPlugin(modules)

local Maid = require("Maid")
