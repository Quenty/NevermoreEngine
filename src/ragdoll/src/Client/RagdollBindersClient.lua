--[=[
	Holds binders
	@class RagdollBindersClient
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(function(self, serviceBag)
	self:Add(Binder.new("Ragdoll", require("RagdollClient"), serviceBag))
	self:Add(Binder.new("Ragdollable", require("RagdollableClient"), serviceBag))

	-- Effects
	self:Add(Binder.new("RagdollHumanoidOnDeath", require("RagdollHumanoidOnDeathClient"), serviceBag))
	self:Add(Binder.new("RagdollHumanoidOnFall", require("RagdollHumanoidOnFallClient"), serviceBag))
end)