--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local packages = require(loader).bootstrapGame(ServerScriptService.ik)

local serviceBag = require(packages.ServiceBag).new()
local ikService = serviceBag:GetService(packages.IKService)

-- Start game
serviceBag:Init()
serviceBag:Start()


-- Build test NPC rigs
local RigBuilderUtils = require(packages.RigBuilderUtils)
RigBuilderUtils.promiseR15MeshRig()
	:Then(function(character)
		local humanoid = character.Humanoid

		-- reparent to middle
		humanoid.RootPart.CFrame = CFrame.new(0, 25, 0)
		character.Parent = workspace
		humanoid.RootPart.CFrame = CFrame.new(0, 25, 0)

		-- look at origin
		RunService.Stepped:Connect(function()
			ikService:UpdateServerRigTarget(humanoid, Vector3.new(0, 0, 0))
		end)
	end)
