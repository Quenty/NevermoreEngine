--[=[
	Ragdolls the humanoid on death. Should be bound via [RagdollBindersClient].

	@client
	@class RagdollHumanoidOnDeathClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BaseObject = require("BaseObject")
local RagdollBindersClient = require("RagdollBindersClient")
local CharacterUtils = require("CharacterUtils")
local RagdollRigging = require("RagdollRigging")

local RagdollHumanoidOnDeathClient = setmetatable({}, BaseObject)
RagdollHumanoidOnDeathClient.ClassName = "RagdollHumanoidOnDeathClient"
RagdollHumanoidOnDeathClient.__index = RagdollHumanoidOnDeathClient

--[=[
	Constructs a new RagdollHumanoidOnDeathClient. Should be done via [Binder]. See [RagdollBindersClient].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollHumanoidOnDeathClient
]=]
function RagdollHumanoidOnDeathClient.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), RagdollHumanoidOnDeathClient)

	self._ragdollBinder = serviceBag:GetService(RagdollBindersClient).Ragdoll

	if self._obj:GetState() == Enum.HumanoidStateType.Dead then
		self:_handleDeath()
	else
		self._maid._diedEvent = self._obj.Died:Connect(function()
			self:_handleDeath(self._obj)
		end)
	end

	return self
end

function RagdollHumanoidOnDeathClient:_getPlayer()
	return CharacterUtils.getPlayerFromCharacter(self._obj)
end

function RagdollHumanoidOnDeathClient:_handleDeath()
	-- Disconnect!
	self._maid._diedEvent = nil

	if self:_getPlayer() == Players.LocalPlayer then
		self._ragdollBinder:BindClient(self._obj)
	end

	local character = self._obj.Parent
	task.delay(Players.RespawnTime - 0.5, function()
		if not character:IsDescendantOf(Workspace) then
			return
		end

		-- fade into the mist...
		RagdollRigging.disableParticleEmittersAndFadeOutYielding(character, 0.4)
	end)
end

return RagdollHumanoidOnDeathClient
