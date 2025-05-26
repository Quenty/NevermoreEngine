--[=[
	Ragdolls the humanoid on death. This class exports a [Binder].
	@server
	@class RagdollCameraShake
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")
local Ragdoll = require("Ragdoll")

local RagdollCameraShake = setmetatable({}, BaseObject)
RagdollCameraShake.ClassName = "RagdollCameraShake"
RagdollCameraShake.__index = RagdollCameraShake

--[=[
	Constructs a new RagdollCameraShake. This class exports a [Binder].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollCameraShake
]=]
function RagdollCameraShake.new(humanoid: Humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), RagdollCameraShake)

	self._serviceBag = assert(serviceBag, "Bad serviceBag")
	self._ragdollBinder = self._serviceBag:GetService(Ragdoll)

	return self
end

return PlayerHumanoidBinder.new("RagdollCameraShake", RagdollCameraShake)
