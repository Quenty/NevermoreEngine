--[=[
	@class RogueHumanoidProperties
]=]

local require = require(script.Parent.loader).load(script)

local StarterPlayer = game:GetService("StarterPlayer")

local RoguePropertyTableDefinition = require("RoguePropertyTableDefinition")

return RoguePropertyTableDefinition.new("RogueHumanoidProperties", {
	WalkSpeed = StarterPlayer.CharacterWalkSpeed;
	JumpHeight = StarterPlayer.CharacterJumpHeight;
	JumpPower = StarterPlayer.CharacterJumpPower;
	CharacterUseJumpPower = StarterPlayer.CharacterUseJumpPower;

	Scale = 1;
	ScaleMax = 20;
	ScaleMin = 0.2;

	MaxHealth = 100;
})