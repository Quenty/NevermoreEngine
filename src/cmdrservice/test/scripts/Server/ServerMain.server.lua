--- Main injection point
-- @script ServerMain
-- @author Quenty

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local LoaderUtils = require(ServerScriptService:FindFirstChild("LoaderUtils", true))

local clientFolder, serverFolder, sharedFolder = LoaderUtils.toWallyFormat(ServerScriptService.cmdrservice)
clientFolder.Parent = ReplicatedStorage
sharedFolder.Parent = ReplicatedStorage
serverFolder.Parent = ServerScriptService

local serviceBag = require(serverFolder.ServiceBag).new()
serviceBag:GetService(require(serverFolder.CmdrService))

serviceBag:Init()
serviceBag:Start()
