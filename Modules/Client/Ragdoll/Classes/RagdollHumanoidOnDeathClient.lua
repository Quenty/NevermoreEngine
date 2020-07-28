--- Ragdolls the humanoid on death
-- @classmod RagdollHumanoidOnDeathClient
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BaseObject = require("BaseObject")
local RagdollBindersClient = require("RagdollBindersClient")
local CharacterUtils = require("CharacterUtils")
local RagdollRigging = require("RagdollRigging")

local RagdollHumanoidOnDeathClient = setmetatable({}, BaseObject)
RagdollHumanoidOnDeathClient.ClassName = "RagdollHumanoidOnDeathClient"
RagdollHumanoidOnDeathClient.__index = RagdollHumanoidOnDeathClient

function RagdollHumanoidOnDeathClient.new(humanid)
	local self = setmetatable(BaseObject.new(humanid), RagdollHumanoidOnDeathClient)

	self._maid:GiveTask(self._obj.Died:Connect(function()
		self:_handleDeath(self._obj)
	end))

	return self
end

function RagdollHumanoidOnDeathClient:_handleDeath()
	local player = CharacterUtils.getPlayerFromCharacter(self._obj)
	if player == Players.LocalPlayer then
		RagdollBindersClient.Ragdoll:BindClient(self._obj)
	end

	local character = self._obj.Parent

	delay(Players.RespawnTime - 0.5, function()
		if not character:IsDescendantOf(Workspace) then
			return
		end

		-- fade into the mist...
		RagdollRigging.disableParticleEmittersAndFadeOutYielding(character, 0.4)
	end)
end

return RagdollHumanoidOnDeathClient