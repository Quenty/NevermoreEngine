--[[
	@class ServerMain
]]

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

serviceBag:GetService(require(serverFolder.CmdrService)):RegisterCommand({
	Name = "explode";
	Aliases = { "boom" };
	Description = "Makes players explode";
	Group = "Admin";
	Args = {
		{
			Type = "players";
			Name = "players";
			Description = "Victims";
		},
	};
}, function(_context, players)
	for _, player in pairs(players) do
		local humanoid = player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
		local humanoidRootPart = humanoid and humanoid.RootPart
		if humanoidRootPart then
			local explosion = Instance.new("Explosion")
			explosion.Position = humanoidRootPart.Position
			explosion.Parent = humanoidRootPart
		end
	end

	return "Exploded!"
end)