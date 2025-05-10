--[[
	@class ServerMain
]]

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.ik)

local serviceBag = require("ServiceBag").new()
local ikService = serviceBag:GetService(require("IKService"))
serviceBag:Init()
serviceBag:Start()

-- Build test NPC rigs
local RigBuilderUtils = require("RigBuilderUtils")
RigBuilderUtils.promiseR15MeshRig():Then(function(character)
	local humanoid = character.Humanoid

	-- reparent to middle
	humanoid.RootPart.CFrame = CFrame.new(0, 25, 0)
	character.Parent = workspace
	humanoid.RootPart.CFrame = CFrame.new(0, 25, 0)

	-- look at origin
	RunService.Stepped:Connect(function()
		ikService:UpdateServerRigTarget(humanoid, Vector3.zero)
	end)
end)
