--- Holds binders
-- @classmod RagdollBindersServer
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(function(self)
	self:Add(Binder.new("Ragdoll", require("Ragdoll")))
	self:Add(Binder.new("Ragdollable", require("Ragdollable")))

	self:Add(Binder.new("RagdollHumanoidOnDeath", require("RagdollHumanoidOnDeath")))
	self:Add(Binder.new("RagdollHumanoidOnFall", require("RagdollHumanoidOnFall")))
end)