--[=[
	@class RogueHumanoidBindersServer
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")

return BinderProvider.new(function(self, serviceBag)
	self:Add(PlayerHumanoidBinder.new("RogueHumanoid", require("RogueHumanoid"), serviceBag))
end)