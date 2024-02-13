--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.conditions)

local AdorneeConditionUtils = require("AdorneeConditionUtils")
local TieDefinition = require("TieDefinition")
local AttributeValue = require("AttributeValue")

do
	local conditionFolder = AdorneeConditionUtils.createConditionContainer()
	conditionFolder.Parent = workspace

	local orGroup = AdorneeConditionUtils.createOrConditionGroup()
	orGroup.Parent = conditionFolder

	AdorneeConditionUtils.createRequiredProperty("Name", "Allowed").Parent = orGroup

	local andGroup = AdorneeConditionUtils.createAndConditionGroup()
	andGroup.Parent = orGroup

	AdorneeConditionUtils.createRequiredProperty("Name", "Allow").Parent = andGroup
	AdorneeConditionUtils.createRequiredAttribute("IsEnabled", true).Parent = andGroup

	local testInst = Instance.new("Folder")
	testInst.Name = "Deny"
	testInst:SetAttribute("IsEnabled", false)
	testInst.Parent = workspace

	AdorneeConditionUtils.observeConditionsMet(conditionFolder, testInst):Subscribe(function(isAllowed)
		print("Is allowed", isAllowed)
	end)

	task.delay(0.1, function()
		testInst.Name = "Allowed"
	end)
end

-- Test tie integration
do
	local door = Instance.new("Folder")
	door.Name = "Door"
	door.Parent = workspace


	local openableInterface = TieDefinition.new("Openable", {
		IsOpen = TieDefinition.Types.PROPERTY;
	})
	openableInterface:Implement(door, {
		IsOpen = AttributeValue.new(door, "IsOpen", false);
	})

	local canOpenCondition = AdorneeConditionUtils.createConditionContainer()
	canOpenCondition.Name = "CanOpenCondition"
	canOpenCondition.Parent = workspace

	AdorneeConditionUtils.createRequiredTieInterface(openableInterface).Parent = canOpenCondition
	AdorneeConditionUtils.createRequiredAttribute("IsOpen", false).Parent = canOpenCondition

	AdorneeConditionUtils.observeConditionsMet(canOpenCondition, door):Subscribe(function(isAllowed)
		print("Is door opening allowed", isAllowed)
	end)
end