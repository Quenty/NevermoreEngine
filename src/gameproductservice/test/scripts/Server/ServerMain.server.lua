--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local packages = require(loader).bootstrapGame(ServerScriptService.gameproduct)

local serviceBag = require(packages.ServiceBag).new()
serviceBag:GetService(packages.GameProductService)

serviceBag:Init()
serviceBag:Start()

serviceBag:GetService(packages.GameConfigService):AddPass("TestProduct", 27825080)

local promptPart = Instance.new("Part")
promptPart.Parent = workspace
promptPart.Anchored = true
promptPart.Name = "promptPart"
promptPart.Size = Vector3.new(1, 1, 1)
promptPart.CFrame = CFrame.new(0, 10, 0)

local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Prompt Pass"
prompt.Parent = promptPart

prompt.Triggered:Connect(function(player)
	serviceBag:GetService(packages.GameProductService):PromptGamePassPurchase(player, 27825080)
end)