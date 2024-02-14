--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.gameproduct)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("GameProductService"))

serviceBag:Init()
serviceBag:Start()

serviceBag:GetService(require("GameConfigService")):AddPass("TestPass", 27825080)
serviceBag:GetService(require("GameConfigService")):AddProduct("TestProduct", 29082053)
serviceBag:GetService(require("GameConfigService")):AddAsset("FrogOnHead", 4556535529)

local GameConfigAssetTypes = require("GameConfigAssetTypes")

local function makePrompt(assetType, idOrKey, cframe)
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	local promptPart = Instance.new("Part")
	promptPart.Parent = workspace
	promptPart.Anchored = true
	promptPart.TopSurface = Enum.SurfaceType.Smooth
	promptPart.BottomSurface = Enum.SurfaceType.Smooth
	promptPart.Name = "promptPart"
	promptPart.Size = Vector3.new(1, 1, 1)
	promptPart.CFrame = cframe

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = string.format("Prompt %s (%s)", assetType, tostring(idOrKey))
	prompt.Parent = promptPart

	prompt.Triggered:Connect(function(player)
		serviceBag:GetService(require("GameProductService")):PromisePromptPurchase(player, assetType, idOrKey)
			:Then(function(purchased)
				print("purchased", idOrKey, purchased)
			end)
	end)
end

makePrompt(GameConfigAssetTypes.ASSET, 9238589603, CFrame.new(0, 5, -20))
makePrompt(GameConfigAssetTypes.PASS, "TestPass", CFrame.new(0, 5, -10))
makePrompt(GameConfigAssetTypes.PASS, 27825080, CFrame.new(0, 5, 0))
makePrompt(GameConfigAssetTypes.PRODUCT, "TestProduct", CFrame.new(0, 5, 10))
makePrompt(GameConfigAssetTypes.PRODUCT, "SpyglassProduct", CFrame.new(0, 5, 20))
makePrompt(GameConfigAssetTypes.ASSET, "FrogOnHead", CFrame.new(0, 5, 30))