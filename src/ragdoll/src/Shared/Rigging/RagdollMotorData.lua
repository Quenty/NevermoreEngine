--[=[
	@class RagdollMotorData
]=]

local require = require(script.Parent.loader).load(script)

local AdorneeData = require("AdorneeData")

return AdorneeData.new({
	IsMotorAnimated = false,
	RagdollSpringReturnSpeed = 20,
})
