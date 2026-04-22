--!strict
--[=[
	@class FakeSkyboxRenderMethod
]=]

local require = require(script.Parent.loader).load(script)

local SimpleEnum = require("SimpleEnum")

export type FakeSkyboxRenderMethod = "surfacegui" | "decal"

return SimpleEnum.new({
	SURFACEGUI = "surfacegui" :: "surfacegui",
	DECAL = "decal" :: "decal",
})
