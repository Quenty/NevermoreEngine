--!strict
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
local ServiceBag = require("ServiceBag")

local RagdollHumanoidOnDeathClient = setmetatable({}, BaseObject)
RagdollHumanoidOnDeathClient.ClassName = "RagdollHumanoidOnDeathClient"
RagdollHumanoidOnDeathClient.__index = RagdollHumanoidOnDeathClient

export type RagdollHumanoidOnDeathClient =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_ragdollBinder: any, -- Binder.Binder<RagdollClient.RagdollClient> (heavy cyclic binder; old solver can't hold it)
		},
		{} :: typeof({ __index = RagdollHumanoidOnDeathClient })
	))
	& BaseObject.BaseObject

function RagdollHumanoidOnDeathClient._getPlayer(self: RagdollHumanoidOnDeathClient): Player?
	return CharacterUtils.getPlayerFromCharacter(self._obj :: Instance)
end

--[=[
	Disables all particle emitters and fades them out. Yields for the duration.

	@yields
	@param character Model
	@param duration number
]=]
function RagdollHumanoidOnDeathClient.disableParticleEmittersAndFadeOutYielding(character: Model, duration: number): ()
	local descendants = character:GetDescendants()
	local transparencies: { [Instance]: number } = {}
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
			(part :: BasePart).Transparency = (1 - alpha) * initialTransparency + alpha
		end
	end
end

function RagdollHumanoidOnDeathClient._handleDeath(self: RagdollHumanoidOnDeathClient): ()
	-- Disconnect!
	self._maid._diedEvent = nil

	local humanoidObj = self._obj :: Humanoid
	if self:_getPlayer() == Players.LocalPlayer then
		self._ragdollBinder:BindClient(humanoidObj)
	end

	local character = humanoidObj.Parent
	self._maid:GiveTask(task.delay(Players.RespawnTime - 0.5, function()
		if not character or not character:IsDescendantOf(Workspace) then
			return
		end

		-- fade into the mist...
		RagdollHumanoidOnDeathClient.disableParticleEmittersAndFadeOutYielding(character :: Model, 0.4)
	end))
end

--[=[
	Constructs a new RagdollHumanoidOnDeathClient. This module exports a [Binder].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollHumanoidOnDeathClient
]=]
function RagdollHumanoidOnDeathClient.new(
	humanoid: Humanoid,
	serviceBag: ServiceBag.ServiceBag
): RagdollHumanoidOnDeathClient
	local self: RagdollHumanoidOnDeathClient =
		setmetatable(BaseObject.new(humanoid) :: any, RagdollHumanoidOnDeathClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._ragdollBinder = self._serviceBag:GetService(RagdollClient)

	local humanoidObj = self._obj :: Humanoid
	if humanoidObj:GetState() == Enum.HumanoidStateType.Dead then
		self:_handleDeath()
	else
		self._maid._diedEvent = humanoidObj.Died:Connect(function()
			self:_handleDeath()
		end)
	end

	return self
end

return Binder.new(
		"RagdollHumanoidOnDeath",
		RagdollHumanoidOnDeathClient :: any
	) :: Binder.Binder<RagdollHumanoidOnDeathClient>
