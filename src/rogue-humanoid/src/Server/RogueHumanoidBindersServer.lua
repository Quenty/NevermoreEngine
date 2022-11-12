--[=[
	@class RogueHumanoidBindersServer
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")

return BinderProvider.new(script.Name, function(self, serviceBag)
	self:Add(PlayerHumanoidBinder.new("RogueHumanoid", require("RogueHumanoid"), serviceBag))
end)