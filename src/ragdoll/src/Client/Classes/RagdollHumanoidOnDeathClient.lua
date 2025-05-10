--[=[
	Ragdolls the humanoid on death. Should be bound via [RagdollBindersClient].

	@client
	@class RagdollHumanoidOnDeathClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local CharacterUtils = require("CharacterUtils")
local RagdollClient = require("RagdollClient")

local RagdollHumanoidOnDeathClient = setmetatable({}, BaseObject)
RagdollHumanoidOnDeathClient.ClassName = "RagdollHumanoidOnDeathClient"
RagdollHumanoidOnDeathClient.__index = RagdollHumanoidOnDeathClient

--[=[
	Constructs a new RagdollHumanoidOnDeathClient. This module exports a [Binder].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollHumanoidOnDeathClient
]=]
function RagdollHumanoidOnDeathClient.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), RagdollHumanoidOnDeathClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._ragdollBinder = self._serviceBag:GetService(RagdollClient)

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
	self._maid:GiveTask(task.delay(Players.RespawnTime - 0.5, function()
		if not character:IsDescendantOf(Workspace) then
			return
		end

		-- fade into the mist...
		RagdollHumanoidOnDeathClient.disableParticleEmittersAndFadeOutYielding(character, 0.4)
	end))
end

--[=[
	Disables all particle emitters and fades them out. Yields for the duration.

	@yields
	@param character Model
	@param duration number
]=]
function RagdollHumanoidOnDeathClient.disableParticleEmittersAndFadeOutYielding(character, duration)
	local descendants = character:GetDescendants()
	local transparencies = {}
	for _, instance in descendants do
		if instance:IsA("BasePart") or instance:IsA("Decal") then
			transparencies[instance] = instance.Transparency
		elseif instance:IsA("ParticleEmitter") then
			instance.Enabled = false
		end
	end
	local t = 0
	while t < duration do
		-- Using heartbeat because we want to update just before rendering next frame, and not
		-- block the render thread kicking off (as RenderStepped does)
		local dt = RunService.Heartbeat:Wait()
		t = t + dt
		local alpha = math.min(t / duration, 1)
		for part, initialTransparency in transparencies do
			part.Transparency = (1 - alpha) * initialTransparency + alpha
		end
	end
end

return Binder.new("RagdollHumanoidOnDeath", RagdollHumanoidOnDeathClient)
