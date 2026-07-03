--!strict
--[=[
	@class RoguePropertyBaseValueTypes
]=]

local require = require(script.Parent.loader).load(script)

local SimpleEnum = require("SimpleEnum")

return SimpleEnum.new({
	INSTANCE = "instance" :: "instance",
	ANY = "any" :: "any",
})
