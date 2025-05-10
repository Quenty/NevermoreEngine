--[[
	@class ArmIKBase.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ArmIKBase = require("ArmIKBase")
local Maid = require("Maid")
local RigBuilderUtils = require("RigBuilderUtils")
local ServiceBag = require("ServiceBag")

return function(_target)
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())

	maid:GivePromise(RigBuilderUtils.promisePlayerRig(4397833)):Then(function(character)
		maid:GiveTask(character)

		local humanoid = character.Humanoid
		local position = Workspace.CurrentCamera.CFrame:pointToWorldSpace(Vector3.new(0, 0, -10))

		local armIKBase = ArmIKBase.new(humanoid, "Right", serviceBag)
		maid:GiveTask(armIKBase)

		local attachment = Instance.new("Attachment")
		attachment.Name = "IKRigStoryTarget"
		attachment.Parent = workspace.Terrain
		attachment.WorldPosition = position + Workspace.CurrentCamera.CFrame:vectorToWorldSpace(Vector3.new(2, 0, 1))
		maid:GiveTask(attachment)

		armIKBase:Grip(attachment)

		humanoid.RootPart.CFrame = CFrame.new(position)
		character.Parent = workspace
		humanoid.RootPart.CFrame = CFrame.new(position)

		maid:GiveTask(RunService.RenderStepped:Connect(function()
			armIKBase:Update()
		end))
	end)

	return function()
		maid:DoCleaning()
	end
end
