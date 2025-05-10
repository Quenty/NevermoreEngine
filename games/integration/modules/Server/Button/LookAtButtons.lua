--[=[
	Makes the character look at nearby physical buttons
	@class LookAtButtons
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")

local LookAtButtons = setmetatable({}, BaseObject)
LookAtButtons.ClassName = "LookAtButtons"
LookAtButtons.__index = LookAtButtons

function LookAtButtons.new(humanoid: Humanoid)
	local self = setmetatable(BaseObject.new(humanoid), LookAtButtons)

	return self
end

return LookAtButtons
