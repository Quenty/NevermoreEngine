--[=[
	Holds binders for Ragdoll system. Be sure to initialize on the client too. See [RagdollBindersClient].
	Be sure to use a [ServiceBag] to initialize this service.

	```lua
	-- Server.lua

	local serviceBag = require("ServiceBag")
	local ragdollBindersServer = serviceBag:GetService(require("RagdollBindersServer"))
	serviceBag:Init()

	ragdollBindersServer.RagdollHumanoidOnDeath:SetAutomaticTagging(false)

	serviceBag:Start()
	```

	@server
	@class RagdollBindersServer
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")

return BinderProvider.new(script.Name, function(self, serviceBag)
--[=[
	Apply this [Binder] to a humanoid to ragdoll it. Humanoid must already have [Ragdollable] defined.

	```lua
	local ragdollBinder = serviceBag:GetService(RagdollBindersClient).Ragdoll

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

	local ragdollBinder = serviceBag:GetService(RagdollBindersClient).Ragdoll
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
	self:Add(Binder.new("Ragdoll", require("Ragdoll"), serviceBag))

--[=[
	Enables ragdolling on a humanoid.
	@prop Ragdollable PlayerHumanoidBinder<Ragdollable>
	@within RagdollBindersServer
]=]
	self:Add(PlayerHumanoidBinder.new("Ragdollable", require("Ragdollable"), serviceBag))

--[=[
	Automatically applies ragdoll upon humanoid death.
	@prop RagdollHumanoidOnDeath PlayerHumanoidBinder<RagdollHumanoidOnDeath>
	@within RagdollBindersServer
]=]
	self:Add(PlayerHumanoidBinder.new("RagdollHumanoidOnDeath", require("RagdollHumanoidOnDeath"), serviceBag))

--[=[
	Automatically applies ragdoll upon humanoid fall.
	@prop RagdollHumanoidOnFall PlayerHumanoidBinder<RagdollHumanoidOnFall>
	@within RagdollBindersServer
]=]
	self:Add(PlayerHumanoidBinder.new("RagdollHumanoidOnFall", require("RagdollHumanoidOnFall"), serviceBag))

--[=[
	Automatically unragdolls the humanoid.
	@prop UnragdollAutomatically PlayerHumanoidBinder<UnragdollAutomatically>
	@within RagdollBindersServer
]=]
	self:Add(PlayerHumanoidBinder.new("UnragdollAutomatically", require("UnragdollAutomatically"), serviceBag))
end)