--[=[
	@class TestMantleConfigProvider
]=]

local require = require(script.Parent.loader).load(script)

local MantleConfigProvider = require("MantleConfigProvider")

return MantleConfigProvider.new(script)