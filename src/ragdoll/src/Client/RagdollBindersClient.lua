--[=[
	Holds binders for Ragdolls on the client. Be sure to initialize on the server. See [RagdollBindersClient] for details.
	Be sure to use a [ServiceBag] to initialize this service.

	```lua
	-- Client.lua

	local serviceBag = require("ServiceBag")
	serviceBag:GetService(require("RagdollBindersClient"))

	serviceBag:Init()
	serviceBag:Start()
	```

	@client
	@class RagdollBindersClient
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(function(self, serviceBag)
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
	self:Add(Binder.new("Ragdoll", require("RagdollClient"), serviceBag))

--[=[
	Enables ragdolling on a humanoid.
	@prop Ragdollable Binder<RagdollableClient>
	@within RagdollBindersClient
]=]
	self:Add(Binder.new("Ragdollable", require("RagdollableClient"), serviceBag))

--[=[
	Automatically applies ragdoll upon humanoid death.
	@prop RagdollaRagdollHumanoidOnDeathble Binder<RagdollHumanoidOnDeathClient>
	@within RagdollBindersClient
]=]
	self:Add(Binder.new("RagdollHumanoidOnDeath", require("RagdollHumanoidOnDeathClient"), serviceBag))

--[=[
	Automatically applies ragdoll upon humanoid fall.
	@prop RagdollHumanoidOnFall Binder<RagdollHumanoidOnFallClient>
	@within RagdollBindersClient
]=]
	self:Add(Binder.new("RagdollHumanoidOnFall", require("RagdollHumanoidOnFallClient"), serviceBag))
end)