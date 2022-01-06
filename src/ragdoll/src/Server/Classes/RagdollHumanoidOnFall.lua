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
local RagdollBindersServer = require("RagdollBindersServer")
local RagdollHumanoidOnFallConstants = require("RagdollHumanoidOnFallConstants")

local RagdollHumanoidOnFall = setmetatable({}, BaseObject)
RagdollHumanoidOnFall.ClassName = "RagdollHumanoidOnFall"
RagdollHumanoidOnFall.__index = RagdollHumanoidOnFall

--[=[
	Constructs a new RagdollHumanoidOnFall. Should be done via [Binder]. See [RagdollBindersServer].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollHumanoidOnFall
]=]
function RagdollHumanoidOnFall.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), RagdollHumanoidOnFall)

	self._ragdollBinder = serviceBag:GetService(RagdollBindersServer).Ragdoll

	local player = CharacterUtils.getPlayerFromCharacter(self._obj)
	if player then
		self._player = player

		self._remoteEvent = Instance.new("RemoteEvent")
		self._remoteEvent.Name = RagdollHumanoidOnFallConstants.REMOTE_EVENT_NAME
		self._remoteEvent.Parent = self._obj
		self._maid:GiveTask(self._remoteEvent)

		self._maid:GiveTask(self._remoteEvent.OnServerEvent:Connect(function(...)
			self:_handleServerEvent(...)
		end))
	else
		self._ragdollLogic = BindableRagdollHumanoidOnFall.new(self._obj, self._ragdollBinder)
		self._maid:GiveTask(self._ragdollLogic)

		self._maid:GiveTask(self._ragdollLogic.ShouldRagdoll.Changed:Connect(function()
			self:_update()
		end))
	end

	return self
end

function RagdollHumanoidOnFall:_handleServerEvent(player, value)
	assert(player == self._player, "Bad player")
	assert(typeof(value) == "boolean", "Bad value")

	if value then
		self._ragdollBinder:Bind(self._obj)
	else
		self._ragdollBinder:Unbind(self._obj)
	end
end

function RagdollHumanoidOnFall:_update()
	if self._ragdollLogic.ShouldRagdoll.Value then
		self._ragdollBinder:Bind(self._obj)
	else
		if self._obj.Health > 0 then
			self._ragdollBinder:Unbind(self._obj)
		end
	end
end

return RagdollHumanoidOnFall