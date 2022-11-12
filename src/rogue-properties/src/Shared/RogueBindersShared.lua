--[=[
	@class RogueBindersShared
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(script.Name, function(self, serviceBag)
	self:Add(Binder.new("RogueMultiplier", require("RogueMultiplier"), serviceBag))
	self:Add(Binder.new("RogueAdditive", require("RogueAdditive"), serviceBag))
	self:Add(Binder.new("RogueSetter", require("RogueSetter"), serviceBag))
end)