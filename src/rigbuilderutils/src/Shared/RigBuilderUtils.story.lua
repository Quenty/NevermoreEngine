--[[
	@class RigBuilderUtils.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Workspace = game:GetService("Workspace")

local Maid = require("Maid")
local RigBuilderUtils = require("RigBuilderUtils")
local CameraStoryUtils = require("CameraStoryUtils")
local Promise = require("Promise")

local function spawnRig(offset, maid, viewportFrame, rig)
	maid:GiveTask(rig)

	-- Is Roblox being weird about this? Yes.
	rig.Parent = Workspace
	spawn(function()
		rig.Parent = viewportFrame
	end)

	rig:SetPrimaryPartCFrame(Workspace.CurrentCamera.CFrame
		* CFrame.new(0, 0, -15)
		* CFrame.new(offset, 0, 0)
		* CFrame.Angles(0, math.pi, 0))
end

return function(target)
	local maid = Maid.new()

	local viewportFrame = CameraStoryUtils.setupViewportFrame(maid, target)

	local rigs = {
		RigBuilderUtils.createR6MeshRig(),
		RigBuilderUtils.createR6MeshBoyRig(),
		RigBuilderUtils.createR6MeshGirlRig(),
		RigBuilderUtils.promiseR15PackageRig(193700907),
		RigBuilderUtils.promiseR15ManRig(),
		RigBuilderUtils.promiseR15WomanRig(),
		RigBuilderUtils.promiseR15MeshRig(),
		RigBuilderUtils.promiseR15Rig(),
		RigBuilderUtils.promisePlayerRig(4397833),
		RigBuilderUtils.promisePlayerRig(9360463),
		RigBuilderUtils.promisePlayerRig(676056)
	}

	for index, rig in rigs do
		local offset = ((index - 0.5)/#rigs - 0.5)*#rigs*4
		if Promise.isPromise(rig) then
			maid:GivePromise(rig):Then(function(actualRig)
				spawnRig(offset, maid, viewportFrame, actualRig)
			end)
		else
			spawnRig(offset, maid, viewportFrame, rig)
		end
	end

	return function()
		maid:DoCleaning()
	end
end