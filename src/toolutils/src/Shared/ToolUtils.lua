--!strict
--[=[
	@class ToolUtils
]=]

local require = require(script.Parent.loader).load(script)

local CharacterUtils = require("CharacterUtils")

local ToolUtils = {}

--[=[
	Gets the equipped humanoid for a given tool
]=]
function ToolUtils.getEquippedHumanoid(tool: Tool): Humanoid?
	assert(typeof(tool) == "Instance", "Bad tool")

	local character = tool.Parent
	if not (character and character:IsA("Model")) then
		return nil
	end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return nil
	end

	return humanoid
end

--[=[
	Gets the equipped player for a given tool
]=]
function ToolUtils.getEquippedPlayer(tool: Tool): Player?
	assert(typeof(tool) == "Instance", "Bad tool")

	local humanoid = ToolUtils.getEquippedHumanoid(tool)
	if not humanoid then
		return nil
	end

	return CharacterUtils.getPlayerFromCharacter(humanoid)
end

return ToolUtils
