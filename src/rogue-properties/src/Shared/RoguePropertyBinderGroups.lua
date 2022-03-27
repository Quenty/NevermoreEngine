--[=[
	@class RoguePropertyBinderGroups
]=]

local require = require(script.Parent.loader).load(script)

local BinderGroup = require("BinderGroup")
local t = require("t")

return require("BinderGroupProvider").new(function(self)
	self:Add("RogueModifiers", BinderGroup.new(
		{},
		t.interface({
			GetObject = t.callback;
		})
	))
end)