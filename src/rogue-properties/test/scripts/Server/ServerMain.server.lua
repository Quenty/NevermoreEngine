--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local packages = require(loader).bootstrapGame(ServerScriptService.rogueproperties)

local serviceBag = require(packages.ServiceBag).new()
serviceBag:GetService(packages.RoguePropertyService)

-- Start game
serviceBag:Init()
serviceBag:Start()

local RoguePropertyTableDefinition = require(packages.RoguePropertyTableDefinition)
local RoguePropertyDefinition = require(packages.RoguePropertyDefinition)

local properties = RoguePropertyTableDefinition.new({
	RoguePropertyDefinition.new("AttackDamage", 30);
	RoguePropertyDefinition.new("AbilityPower", 30);
})

local attackDamage = properties.AttackDamage:Get(serviceBag, workspace)
local abilityPower = properties.AbilityPower:Get(serviceBag, workspace)

attackDamage:Observe():Subscribe(function(value)
	print("Attack damage", value)
end)
abilityPower:Observe():Subscribe(function(value)
	print("Ability power", value)
end)

attackDamage:CreateMultiplier(2, workspace)
attackDamage:CreateAdditive(100, workspace)

print(attackDamage:GetValue())

attackDamage:ObserveSourcesBrio():Subscribe(function(value)
	print(value:GetValue())
end)