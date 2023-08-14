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

local properties = RoguePropertyTableDefinition.new("CombatStats", {
	Health = 100;

	Ultimate = {
		AttackDamage = 30;
		AbilityPower = 30;
	};

	HeavyPunch = {
		AttackDamage = 45;
		AbilityPower = 100;
	};
})

local propertyTable = properties:GetPropertyTable(serviceBag, workspace)
local ultAttackDamage = properties.Ultimate.AttackDamage:Get(serviceBag, workspace)
local ultAbilityPower = properties.Ultimate.AbilityPower:Get(serviceBag, workspace)

ultAttackDamage:Observe():Subscribe(function(value)
	print("Attack damage", value)
end)
ultAbilityPower:Observe():Subscribe(function(value)
	print("Ability power", value)
end)

propertyTable.Changed:Connect(function()
	print("WE CHANGED", propertyTable.Value)
end)

propertyTable:SetBaseValue({
	Health = 5;

	Ultimate = {
		AttackDamage = 2;
		AbilityPower = 2;
	};

	HeavyPunch = {
		AttackDamage = 5;
		AbilityPower = 9;
	};
})

propertyTable.Value = {
	Health = 25000;
};

-- local multiplier = ultAttackDamage:CreateMultiplier(2, workspace)
-- ultAttackDamage:CreateAdditive(100, workspace)

-- print(ultAttackDamage:GetValue())

-- ultAttackDamage:ObserveSourcesBrio():Subscribe(function(value)
-- 	print(value:GetValue())
-- end)

-- multiplier:Destroy()