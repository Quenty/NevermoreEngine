--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local packages = require(loader).bootstrapGame(ServerScriptService.secrets)

local serviceBag = require(packages.ServiceBag).new()
serviceBag:GetService(packages.SecretsService)

-- Start game
serviceBag:Init()
serviceBag:Start()

serviceBag:GetService(packages.SecretsService):SetPublicKeySeed(1523523523)
serviceBag:GetService(packages.SecretsService):StoreSecret("test", "36dfda27-1ba4-42f3-92ff-79262fc7a6e6")

serviceBag:GetService(packages.SecretsService):PromiseSecret("test")
	:Then(function(value)
		print("Got secret", value)
	end)