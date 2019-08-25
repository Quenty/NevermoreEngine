--- Client side ragdolling meant to be used with a binder
-- @classmod RagdollClient

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local RagdollBase = require("RagdollBase")

local RagdollClient = setmetatable({}, RagdollBase)
RagdollClient.ClassName = "RagdollClient"
RagdollClient.__index = RagdollClient

function RagdollClient.new(humanoid)
	local self = setmetatable(RagdollBase.new(humanoid), RagdollClient)

	self:_setupState()
	self:StopAnimations()

	return self
end

function RagdollClient:_setupState()
	self._obj.BreakJointsOnDeath = false

	self._obj:ChangeState(Enum.HumanoidStateType.Physics)
	self._maid:GiveTask(function()
		self._obj:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)
end

return RagdollClient