--- Base object for ragdolls, meant to be used with binders
-- @classmod RagdollBase

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")

local RagdollBase = setmetatable({}, BaseObject)
RagdollBase.ClassName = "RagdollBase"
RagdollBase.__index = RagdollBase

function RagdollBase.new(humanoid)
	local self = setmetatable(BaseObject.new(humanoid), RagdollBase)

	assert(humanoid and typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"))

	return self
end

function RagdollBase:StopAnimations()
	for _, item in pairs(self._obj:GetPlayingAnimationTracks()) do
		item:Stop()
	end
end

return RagdollBase