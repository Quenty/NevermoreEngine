--!strict
--[=[
	When a humanoid is bound with this, it will ragdoll upon falling. Recommended that you use
	[UnragdollAutomatically] in conjunction with this.

	@server
	@class RagdollHumanoidOnFall
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local BindableRagdollHumanoidOnFall = require("BindableRagdollHumanoidOnFall")
local CharacterUtils = require("CharacterUtils")
local Observable = require("Observable")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")
local Ragdoll = require("Ragdoll")
local RagdollHumanoidOnFallConstants = require("RagdollHumanoidOnFallConstants")
local ServiceBag = require("ServiceBag")

local RagdollHumanoidOnFall = setmetatable({}, BaseObject)
RagdollHumanoidOnFall.ClassName = "RagdollHumanoidOnFall"
RagdollHumanoidOnFall.__index = RagdollHumanoidOnFall

export type RagdollHumanoidOnFall =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_ragdollBinder: typeof(Ragdoll),
			_player: Player?,
			_remoteEvent: RemoteEvent?,
			_ragdollLogic: BindableRagdollHumanoidOnFall.BindableRagdollHumanoidOnFall?,
		},
		{} :: typeof({ __index = RagdollHumanoidOnFall })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new RagdollHumanoidOnFall. Should be done via [Binder]. See [Ragdoll].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollHumanoidOnFall
]=]
function RagdollHumanoidOnFall.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag): RagdollHumanoidOnFall
	local self: RagdollHumanoidOnFall = setmetatable(BaseObject.new(humanoid) :: any, RagdollHumanoidOnFall)

	self._serviceBag = assert(serviceBag, "Bad serviceBag")
	self._ragdollBinder = self._serviceBag:GetService(Ragdoll)

	local player = CharacterUtils.getPlayerFromCharacter(self._obj :: Humanoid)
	if player then
		self._player = player

		local remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = RagdollHumanoidOnFallConstants.REMOTE_EVENT_NAME
		remoteEvent.Archivable = false
		remoteEvent.Parent = self._obj
		self._remoteEvent = remoteEvent
		self._maid:GiveTask(remoteEvent)

		self._maid:GiveTask(remoteEvent.OnServerEvent:Connect(function(...)
			self:_handleServerEvent(...)
		end))
	else
		self._maid:GiveTask(self:_getOrCreateRagdollLogic().ShouldRagdoll.Changed:Connect(function()
			self:_update()
		end))
	end

	return self
end

function RagdollHumanoidOnFall.ObserveIsFalling(self: RagdollHumanoidOnFall): Observable.Observable<boolean>
	-- TODO: Remove logic if nothing is observing it
	return self:_getOrCreateRagdollLogic():ObserveIsFalling()
end

function RagdollHumanoidOnFall._getOrCreateRagdollLogic(
	self: RagdollHumanoidOnFall
): BindableRagdollHumanoidOnFall.BindableRagdollHumanoidOnFall
	if self._ragdollLogic then
		return self._ragdollLogic
	end

	local ragdollLogic = self._maid:Add(BindableRagdollHumanoidOnFall.new(self._obj :: Humanoid, self._ragdollBinder))
	self._ragdollLogic = ragdollLogic

	return ragdollLogic
end

function RagdollHumanoidOnFall._handleServerEvent(self: RagdollHumanoidOnFall, player: Player, value: any): ()
	assert(player == self._player, "Bad player")
	assert(typeof(value) == "boolean", "Bad value")

	if value then
		self._ragdollBinder:Bind(self._obj :: Humanoid)
	else
		self._ragdollBinder:Unbind(self._obj :: Humanoid)
	end
end

function RagdollHumanoidOnFall._update(self: RagdollHumanoidOnFall): ()
	local ragdollLogic = self:_getOrCreateRagdollLogic()
	if ragdollLogic.ShouldRagdoll.Value then
		self._ragdollBinder:Bind(self._obj :: Humanoid)
	else
		if (self._obj :: Humanoid).Health > 0 then
			self._ragdollBinder:Unbind(self._obj :: Humanoid)
		end
	end
end

return PlayerHumanoidBinder.new(
		"RagdollHumanoidOnFall",
		RagdollHumanoidOnFall :: any
	) :: PlayerHumanoidBinder.PlayerHumanoidBinder<RagdollHumanoidOnFall>
