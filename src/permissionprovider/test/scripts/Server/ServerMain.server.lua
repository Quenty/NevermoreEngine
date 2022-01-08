--[[
	@class ServerMain
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local LoaderUtils = require(ServerScriptService:FindFirstChild("LoaderUtils", true))

local clientFolder, serverFolder, sharedFolder = LoaderUtils.toWallyFormat(ServerScriptService.permissionprovider)
clientFolder.Parent = ReplicatedStorage
sharedFolder.Parent = ReplicatedStorage
serverFolder.Parent = ServerScriptService

local serviceBag = require(serverFolder:FindFirstChild("ServiceBag", true)).new()
serviceBag:GetService(require(serverFolder.PermissionService))

serviceBag:Init()
serviceBag:Start()
