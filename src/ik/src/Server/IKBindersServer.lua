--- Holds binders
-- @classmod IKBindersServer
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(function(self, serviceBag)
	-- Rig
	self:Add(Binder.new("IKRig", require("IKRig"), serviceBag))

	-- Grips
	self:Add(Binder.new("IKRightGrip", require("IKRightGrip"), serviceBag))
	self:Add(Binder.new("IKLeftGrip", require("IKLeftGrip"), serviceBag))
end)