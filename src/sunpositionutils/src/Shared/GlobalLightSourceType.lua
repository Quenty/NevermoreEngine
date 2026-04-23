--!strict
--[=[
	@class GlobalLightSourceType
]=]

local require = require(script.Parent.loader).load(script)

local SimpleEnum = require("SimpleEnum")

export type GlobalLightSourceType = "sun" | "moon"

return SimpleEnum.new({
	SUN = "sun" :: "sun",
	MOON = "moon" :: "moon",
})
