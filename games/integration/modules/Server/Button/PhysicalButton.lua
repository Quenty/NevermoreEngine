--[=[
	@class PhysicalButton
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local CharacterUtils = require("CharacterUtils")
local PhysicalButtonConstants = require("PhysicalButtonConstants")
local Ragdoll = require("Ragdoll")

local PhysicalButton = setmetatable({}, BaseObject)
PhysicalButton.ClassName = "PhysicalButton"
PhysicalButton.__index = PhysicalButton

function PhysicalButton.new(obj, serviceBag)
	local self = setmetatable(BaseObject.new(obj), PhysicalButton)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._ragdoll = self._serviceBag:GetService(Ragdoll)

	self._remoteEvent = Instance.new("RemoteEvent")
	self._remoteEvent.Name = PhysicalButtonConstants.REMOTE_EVENT_NAME
	self._remoteEvent.Archivable = false
	self._remoteEvent.Parent = self._obj
	self._maid:GiveTask(self._remoteEvent)

	self._maid:GiveTask(self._remoteEvent.OnServerEvent:Connect(function(...)
		self:_handleRemoteEvent(...)
	end))

	return self
end

function PhysicalButton:_handleRemoteEvent(player: Player)
	local humanoid = CharacterUtils.getAlivePlayerHumanoid(player)
	if not humanoid then
		return
	end

	if self._ragdoll:Get(humanoid) then
		self._ragdoll:Unbind(humanoid)
	else
		self._ragdoll:Bind(humanoid)
	end
end

return PhysicalButton