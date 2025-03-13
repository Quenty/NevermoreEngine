--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.cmdrservice)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("CmdrService"))
serviceBag:Init()
serviceBag:Start()

serviceBag:GetService(require("CmdrService")):RegisterCommand({
	Name = "explode";
	Aliases = { "boom" };
	Description = "Makes players explode";
	Group = "Admin";
	Args = {
		{
			Name = "Players";
			Type = "players";
			Description = "Victims";
		},
	};
}, function(_context, players)
	for _, player in players do
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