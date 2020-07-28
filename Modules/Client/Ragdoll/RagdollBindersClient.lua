--- Holds binders
-- @classmod RagdollBindersClient
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(function(self)
	self:Add(Binder.new("Ragdoll", require("RagdollClient")))
	self:Add(Binder.new("Ragdollable", require("RagdollableClient")))

	-- Effects
	self:Add(Binder.new("RagdollHumanoidOnDeath", require("RagdollHumanoidOnDeathClient")))
	self:Add(Binder.new("RagdollHumanoidOnFall", require("RagdollHumanoidOnFallClient")))
end)