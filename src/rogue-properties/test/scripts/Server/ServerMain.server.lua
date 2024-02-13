--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.rogueproperties)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("RoguePropertyService"))
serviceBag:Init()
serviceBag:Start()

local RoguePropertyTableDefinition = require("RoguePropertyTableDefinition")

local propertyDefinition = RoguePropertyTableDefinition.new("CombatStats", {
	Health = 100;

	Ultimate = {
		AttackDamage = 30;
		AbilityPower = 30;

		Sequence = {
			{
				Name = "Ultimate 1";
				AnimationId = "rbxassetid://1";
			};
			{
				Name = "Ultimate 2";
				AnimationId = "rbxassetid://2";
			};
		};
	};

	HeavyPunch = {
		AttackDamage = 45;
		AbilityPower = 100;

		Sequence = {
			{
				Name = "HeavyPunch 1";
				AnimationId = "rbxassetid://1";
			};
			{
				Name = "HeavyPunch 2";
				AnimationId = "rbxassetid://2";
			};
		};
	};

	ReticleHairRotationsDegree = { 0, 120, 240 };
})

local properties = propertyDefinition:GetPropertyTable(serviceBag, workspace)
local ultAttackDamage = propertyDefinition.Ultimate.AttackDamage:Get(serviceBag, workspace)
-- local ultAbilityPower = propertyDefinition.Ultimate.AbilityPower:Get(serviceBag, workspace)

-- ultAttackDamage:Observe():Subscribe(function(value)
-- 	print("--> Attack damage", value)
-- end)
-- ultAbilityPower:Observe():Subscribe(function(value)
-- 	print("--> Ability power", value)
-- end)

print("sequence", properties.Ultimate.Sequence.Value)
print("ReticleHairRotationsDegree", properties.ReticleHairRotationsDegree.Value)

properties.Changed:Connect(function()
	print("WE CHANGED", properties.Value)
end)

properties:SetBaseValue({
	Health = 5;

	Ultimate = {
		AttackDamage = 2;
		AbilityPower = 2;
	};

	HeavyPunch = {
		AttackDamage = 5;
		AbilityPower = 9;
	};

	ReticleHairRotationsDegree = { 1, 25, 135, 325, 500 };
})

-- print("ReticleHairRotationsDegree", properties.ReticleHairRotationsDegree.Value)

properties.ReticleHairRotationsDegree.Value = { 2, 5}

-- print("ReticleHairRotationsDegree", properties.ReticleHairRotationsDegree.Value)

properties.Health.Value = 25

-- print("properties.Ultimate.Sequence", properties.Ultimate.Sequence.Value)

properties.Ultimate.Sequence.Value = {
	{
		Name = "Another value 3";
		AnimationId = "rbxassetid://3";
	};
}

-- print("properties.Ultimate.Sequence", properties.Ultimate.Sequence.Value)

properties.Value = {
	Health = 25000;
};


local multiplier = ultAttackDamage:CreateMultiplier(2, workspace)
-- ultAttackDamage:CreateAdditive(100, workspace)

-- print(ultAttackDamage:GetValue())

-- ultAttackDamage:ObserveSourcesBrio():Subscribe(function(value)
-- 	print(value:GetValue())
-- end)

multiplier:Destroy()