--- Main injection point
-- @script ServerMain
-- @author Quenty

local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local packages = require(loader).bootstrapGame(ServerScriptService.integration)

local serviceBag = require(packages.ServiceBag).new()
serviceBag:GetService(packages.GameServiceServer)
serviceBag:Init()
serviceBag:Start()