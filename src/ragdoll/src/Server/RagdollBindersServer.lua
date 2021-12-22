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
	self:Add(PlayerHumanoidBinder.new("RagdollHumanoidOnFall", require("RagdollHumanoidOnFall"), serviceBag))
	self:Add(PlayerHumanoidBinder.new("UnragdollAutomatically", require("UnragdollAutomatically"), serviceBag))

	self.RagdollHumanoidOnDeath:SetAutomaticTagging(true)
	self.RagdollHumanoidOnFall:SetAutomaticTagging(true)
	self.UnragdollAutomatically:SetAutomaticTagging(true)
end)