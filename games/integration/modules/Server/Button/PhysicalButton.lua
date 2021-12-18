---
-- @classmod PhysicalButton
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local PhysicalButtonConstants = require("PhysicalButtonConstants")
local RagdollBindersServer = require("RagdollBindersServer")
local CharacterUtils = require("CharacterUtils")

local PhysicalButton = setmetatable({}, BaseObject)
PhysicalButton.ClassName = "PhysicalButton"
PhysicalButton.__index = PhysicalButton

function PhysicalButton.new(obj, serviceBag)
	local self = setmetatable(BaseObject.new(obj), PhysicalButton)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._ragdollBinders = self._serviceBag:GetService(RagdollBindersServer)

	self._remoteEvent = Instance.new("RemoteEvent")
	self._remoteEvent.Name = PhysicalButtonConstants.REMOTE_EVENT_NAME
	self._remoteEvent.Parent = self._obj
	self._maid:GiveTask(self._remoteEvent)

	self._maid:GiveTask(self._remoteEvent.OnServerEvent:Connect(function(...)
		self:_handleRemoteEvent(...)
	end))

	return self
end

function PhysicalButton:_handleRemoteEvent(player)
	local humanoid = CharacterUtils.getAlivePlayerHumanoid(player)
	if not humanoid then
		return
	end

	if self._ragdollBinders.Ragdoll:Get(humanoid) then
		self._ragdollBinders.Ragdoll:Unbind(humanoid)
	else
		self._ragdollBinders.Ragdoll:Bind(humanoid)
	end
end

return PhysicalButton