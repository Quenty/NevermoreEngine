--!strict
--[=[
	Shakes the camera on ragdoll. This class exports a [Binder].
	@server
	@class RagdollCameraShake
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")
local Ragdoll = require("Ragdoll")
local ServiceBag = require("ServiceBag")

local RagdollCameraShake = setmetatable({}, BaseObject)
RagdollCameraShake.ClassName = "RagdollCameraShake"
RagdollCameraShake.__index = RagdollCameraShake

export type RagdollCameraShake =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_ragdollBinder: any,
		},
		{} :: typeof({ __index = RagdollCameraShake })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new RagdollCameraShake. This class exports a [Binder].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollCameraShake
]=]
function RagdollCameraShake.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag): RagdollCameraShake
	local self: RagdollCameraShake = setmetatable(BaseObject.new(humanoid) :: any, RagdollCameraShake)

	self._serviceBag = assert(serviceBag, "Bad serviceBag")
	self._ragdollBinder = self._serviceBag:GetService(Ragdoll)

	return self
end

return PlayerHumanoidBinder.new(
		"RagdollCameraShake",
		RagdollCameraShake :: any
	) :: PlayerHumanoidBinder.PlayerHumanoidBinder<RagdollCameraShake>
