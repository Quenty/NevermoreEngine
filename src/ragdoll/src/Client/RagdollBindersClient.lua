--!strict
--[=[
	Holds binders for Ragdolls on the client. Be sure to initialize on the server. See [RagdollBindersClient] for details.
	Be sure to use a [ServiceBag] to initialize this service.

	:::tip
	Binders can be retrieved directly through a [ServiceBag] now.
	:::

	@client
	@deprecated 15.11.2
	@class RagdollBindersClient
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")

return BinderProvider.new(script.Name, function(self, serviceBag)
	--[=[
	Apply this binder to a humanoid to ragdoll it. Humanoid must already have [Ragdollable] defined.

	```lua
	local ragdoll = serviceBag:GetService(RagdollBindersClient).Ragdoll:Get(humanoid)
	if ragdoll then
		print("Is ragdolled")
	else
		print("Not ragdolled")
	end
	```
	@prop Ragdoll Binder<RagdollClient>
	@within RagdollBindersClient
]=]
	self:Add(serviceBag:GetService(require("RagdollClient")))

	--[=[
	Enables ragdolling on a humanoid.
	@prop Ragdollable Binder<RagdollableClient>
	@within RagdollBindersClient
]=]
	self:Add(serviceBag:GetService(require("RagdollableClient")))

	--[=[
	Automatically applies ragdoll upon humanoid death.
	@prop RagdollaRagdollHumanoidOnDeathble Binder<RagdollHumanoidOnDeathClient>
	@within RagdollBindersClient
]=]
	self:Add(serviceBag:GetService(require("RagdollHumanoidOnDeathClient")))

	--[=[
	Automatically applies ragdoll upon humanoid fall.
	@prop RagdollHumanoidOnFall Binder<RagdollHumanoidOnFallClient>
	@within RagdollBindersClient
]=]
	self:Add(serviceBag:GetService(require("RagdollHumanoidOnFallClient")))
end)
