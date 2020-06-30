--- Utility mehtods for ragdolling. See Ragdoll.lua and RagdollClient.lua for implementation details
-- @module RagdollUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")

local RagdollUtils = {}

local EMPTY_FUNCTION = function() end

function RagdollUtils.setupState(humanoid)
	local maid = Maid.new()

	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	maid:GiveTask(function()
		maid:DoCleaning() -- GC other events
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)

	maid:GiveTask(humanoid.StateChanged:Connect(function()
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end))

	return maid
end

function RagdollUtils.setupHead(humanoid)
	local model = humanoid.Parent
	if not model then
		return EMPTY_FUNCTION
	end

	local head = model:FindFirstChild("Head")
	if not head then
		return EMPTY_FUNCTION
	end

	local originalSize = head.Size
	head.Size = Vector3.new(1, 1, 1)

	return function()
		head.Size = originalSize
	end
end

return RagdollUtils