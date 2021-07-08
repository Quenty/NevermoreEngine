---
-- @classmod RagdollHumanoidOnFall
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local BindableRagdollHumanoidOnFall = require("BindableRagdollHumanoidOnFall")
local CharacterUtils = require("CharacterUtils")
local RagdollBindersServer = require("RagdollBindersServer")
local RagdollHumanoidOnFallConstants = require("RagdollHumanoidOnFallConstants")

local RagdollHumanoidOnFall = setmetatable({}, BaseObject)
RagdollHumanoidOnFall.ClassName = "RagdollHumanoidOnFall"
RagdollHumanoidOnFall.__index = RagdollHumanoidOnFall

function RagdollHumanoidOnFall.new(humanoid)
	local self = setmetatable(BaseObject.new(humanoid), RagdollHumanoidOnFall)

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
		self._ragdollLogic = BindableRagdollHumanoidOnFall.new(self._obj, RagdollBindersServer.Ragdoll)
		self._maid:GiveTask(self._ragdollLogic)

		self._maid:GiveTask(self._ragdollLogic.ShouldRagdoll.Changed:Connect(function()
			self:_update()
		end))
	end

	return self
end

function RagdollHumanoidOnFall:_handleServerEvent(player, value)
	assert(player == self._player)
	assert(typeof(value) == "boolean")

	if value then
		RagdollBindersServer.Ragdoll:Bind(self._obj)
	else
		RagdollBindersServer.Ragdoll:Unbind(self._obj)
	end
end

function RagdollHumanoidOnFall:_update()
	if self._ragdollLogic.ShouldRagdoll.Value then
		RagdollBindersServer.Ragdoll:Bind(self._obj)
	else
		if self._obj.Health > 0 then
			RagdollBindersServer.Ragdoll:Unbind(self._obj)
		end
	end
end

return RagdollHumanoidOnFall