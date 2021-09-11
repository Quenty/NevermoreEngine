--- Holds binders
-- @classmod HideBinders
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(function(self, serviceBag)
	self:Add(Binder.new("Hide", require("HideClient"), serviceBag))
end)