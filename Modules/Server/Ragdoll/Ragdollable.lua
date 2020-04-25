---
-- @classmod Ragdollable
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local RagdollRigging = require("RagdollRigging")
local RagdollConstants = require("RagdollConstants")
local CharacterUtils = require("CharacterUtils")

local Ragdollable = setmetatable({}, BaseObject)
Ragdollable.ClassName = "Ragdollable"
Ragdollable.__index = Ragdollable

function Ragdollable.new(humanoid)
	local self = setmetatable(BaseObject.new(humanoid), Ragdollable)

	local player = CharacterUtils.getPlayerFromCharacter(self._obj)
	if player then
		self._remoteEvent = Instance.new("RemoteEvent")
		self._remoteEvent.Name = RagdollConstants.RAGDOLL_REMOTE_EVENT
		self._remoteEvent.Parent = self._obj
		self._maid:GiveTask(self._remoteEvent)
	end

	self._obj.BreakJointsOnDeath = false
	RagdollRigging.createRagdollJoints(self._obj.Parent, humanoid.RigType)

	return self
end

return Ragdollable