--!strict
--[=[
	@class ModelTransparencyMode
]=]

local require = require(script.Parent.loader).load(script)

local SimpleEnum = require("SimpleEnum")

export type ModelTransparencyMode = "SetTransparency" | "SetLocalTransparencyModifier"

return SimpleEnum.new({
	TRANSPARENCY = "SetTransparency" :: "SetTransparency",
	LOCAL_TRANSPARENCY = "SetLocalTransparencyModifier" :: "SetLocalTransparencyModifier",
})
