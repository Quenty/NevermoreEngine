--!strict
--[=[
	The server half of [AccessPlayerBase]. Adds the things only a server may do: forcing a fact, and
	saying whether a policy is actually running against this player.

	Bound to every player automatically -- reach it with `AccessPlayerInterface:Find(player)` rather than
	by requiring this module, so consumers do not depend on the package.

	@server
	@class AccessPlayer
]=]

local require = require(script.Parent.loader).load(script)

local AccessPlayerBase = require("AccessPlayerBase")
local AccessPlayerInterface = require("AccessPlayerInterface")
local AccessPolicyService = require("AccessPolicyService")
local Binder = require("Binder")
local PlayerBinder = require("PlayerBinder")
local ServiceBag = require("ServiceBag")

local AccessPlayer = setmetatable({}, AccessPlayerBase)
AccessPlayer.ClassName = "AccessPlayer"
AccessPlayer.__index = AccessPlayer

export type AccessPlayer =
	typeof(setmetatable(
		{} :: {
			_accessPolicyService: any,
		},
		{} :: typeof({ __index = AccessPlayer })
	))
	& AccessPlayerBase.AccessPlayerBase

function AccessPlayer.new(player: Player, serviceBag: ServiceBag.ServiceBag): AccessPlayer
	local self: AccessPlayer = setmetatable(AccessPlayerBase.new(player, serviceBag) :: any, AccessPlayer)

	self._accessPolicyService = self._serviceBag:GetService(AccessPolicyService)

	self._maid:GiveTask(AccessPlayerInterface.Server:Implement(self._obj :: Instance, self :: any))

	return self
end

--[=[
	Forces a fact for this player, whatever its layers say. Pass nil to force unresolved.

	@param factName string
	@param value boolean?
	@return () -> () -- Clears this override
]=]
function AccessPlayer.SetFactOverride(self: AccessPlayer, factName: string, value: boolean?): () -> ()
	return self._accessDataService:SetFactOverride(self._obj, factName, value)
end

--[=[
	@param factName string
]=]
function AccessPlayer.ClearFactOverride(self: AccessPlayer, factName: string): ()
	return self._accessDataService:ClearFactOverride(self._obj, factName)
end

--[=[
]=]
function AccessPlayer.ClearFactOverrides(self: AccessPlayer): ()
	return self._accessDataService:ClearFactOverrides(self._obj)
end

--[=[
	Whether a policy is active for this player: enabled, in this realm, and tracking them.

	No `ForPlayer` suffix here, unlike [AccessPolicyService] and [AccessPolicy]: this object *is* a player,
	so the suffix would name something already in the receiver. The rule is that a method says `ForPlayer`
	exactly when it takes one.

	@param policyName string
	@return boolean
]=]
function AccessPlayer.IsPolicyActive(self: AccessPlayer, policyName: string): boolean
	return self._accessPolicyService:IsPolicyActiveForPlayer(self._obj, policyName)
end

return PlayerBinder.new("AccessPlayer", AccessPlayer :: any) :: Binder.Binder<AccessPlayer>
