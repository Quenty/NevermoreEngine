--- Holds binders
-- @classmod RagdollBindersServer
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(function(self, serviceBag)
	self:Add(Binder.new("Ragdoll", require("Ragdoll"), serviceBag))
	self:Add(Binder.new("Ragdollable", require("Ragdollable"), serviceBag))

	self:Add(Binder.new("RagdollHumanoidOnDeath", require("RagdollHumanoidOnDeath"), serviceBag))
	self:Add(Binder.new("RagdollHumanoidOnFall", require("RagdollHumanoidOnFall"), serviceBag))
end)