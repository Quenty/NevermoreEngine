--[=[
	Holds binders for Ragdoll system. Be sure to initialize on the client too. See [RagdollBindersClient].
	Be sure to use a [ServiceBag] to initialize this service.

	:::tip
	Binders can be retrieved directly through a [ServiceBag] now.
	:::

	@server
	@deprecated 15.11.2
	@class RagdollBindersServer
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")

return BinderProvider.new(script.Name, function(self, serviceBag)
	--[=[
	Apply this [Binder] to a humanoid to ragdoll it. Humanoid must already have [Ragdollable] defined.

	```lua
	local ragdollBinder = serviceBag:GetService(RagdollBindersServer).Ragdoll

	local ragdoll = ragdollBinder:Get(humanoid)
	if ragdoll then
		print("Is ragdolled")
		ragdollBinder:Unbind(humanoid)
	else
		print("Not ragdolled")
		ragdollBinder:Bind(humanoid)
	end
	```

	You can also use [RxBinderUtils.observeBoundClass] to observe whether a humanoid is ragdolled using an [Observable].

	:::info
	Like any usage of [Observable], be sure to give the [Subscription] to a [Maid] (or call
	[Subscription.Destroy] on it) once done with the event connection.
	:::

	```lua
	local maid = Maid.new()

	local ragdollBinder = serviceBag:GetService(RagdollBindersServer).Ragdoll
	maid:GiveTask(RxBinderUtils.observeBoundClass(ragdollBinder, humanoid):Subscribe(function(ragdoll)
		if ragdoll then
			print("Ragdolled!")
		else
			print("Not ragdolled")
		end
	end))
	```

	@prop Ragdoll Binder<Ragdoll>
	@within RagdollBindersServer
]=]
	self:Add(serviceBag:GetService(require("Ragdoll")))

	--[=[
	Enables ragdolling on a humanoid.
	@prop Ragdollable PlayerHumanoidBinder<Ragdollable>
	@within RagdollBindersServer
]=]
	self:Add(serviceBag:GetService(require("Ragdollable")))

	--[=[
	Automatically applies ragdoll upon humanoid death.
	@prop RagdollHumanoidOnDeath PlayerHumanoidBinder<RagdollHumanoidOnDeath>
	@within RagdollBindersServer
]=]
	self:Add(serviceBag:GetService(require("RagdollHumanoidOnDeath")))

	--[=[
	Automatically applies ragdoll upon humanoid fall.
	@prop RagdollHumanoidOnFall PlayerHumanoidBinder<RagdollHumanoidOnFall>
	@within RagdollBindersServer
]=]
	self:Add(serviceBag:GetService(require("RagdollHumanoidOnFall")))

	--[=[
	Automatically unragdolls the humanoid.
	@prop UnragdollAutomatically PlayerHumanoidBinder<UnragdollAutomatically>
	@within RagdollBindersServer
]=]
	self:Add(serviceBag:GetService(require("UnragdollAutomatically")))
end)
