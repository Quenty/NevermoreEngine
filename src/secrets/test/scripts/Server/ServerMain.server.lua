--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.secrets)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("SecretsService"))
serviceBag:Init()
serviceBag:Start()

serviceBag:GetService(require("SecretsService")):SetPublicKeySeed(1523523523)
serviceBag:GetService(require("SecretsService")):StoreSecret("test", "36dfda27-1ba4-42f3-92ff-79262fc7a6e6")

serviceBag:GetService(require("SecretsService")):PromiseSecret("test")
	:Then(function(value)
		print("Got secret", value)
	end)