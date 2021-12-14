--- Holds binders
-- @classmod RagdollBindersServer
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")

return BinderProvider.new(function(self, serviceBag)
	self:Add(Binder.new("Ragdoll", require("Ragdoll"), serviceBag))
	self:Add(PlayerHumanoidBinder.new("Ragdollable", require("Ragdollable"), serviceBag))

	self:Add(PlayerHumanoidBinder.new("RagdollHumanoidOnDeath", require("RagdollHumanoidOnDeath"), serviceBag))
	self:Add(Binder.new("RagdollHumanoidOnFall", require("RagdollHumanoidOnFall"), serviceBag))
	self:Add(Binder.new("UnragdollAutomatically", require("UnragdollAutomatically"), serviceBag))
end)