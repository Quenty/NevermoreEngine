--- Providers screenGuis with a given display order for easy use
-- @module GenericScreenGuiProvider
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local String = require("String")
local PlayerGuiUtils = require("PlayerGuiUtils")

local GenericScreenGuiProvider = {}
GenericScreenGuiProvider.ClassName = GenericScreenGuiProvider

function GenericScreenGuiProvider.new(orders)
	assert(type(orders) == "table")

	local self = setmetatable({
		_order = orders;
	}, GenericScreenGuiProvider)

	return self
end

function GenericScreenGuiProvider:__index(index)
	if GenericScreenGuiProvider[index] then
		return GenericScreenGuiProvider[index]
	end

	error(("Bad index %q"):format(tostring(index)), 2)
end

function GenericScreenGuiProvider:__newindex(index, value)
	error(("Bad index %q"):format(tostring(index)), 2)
end

--- Returns a new ScreenGui at DisplayOrder specified
-- @tparam string orderName Order name of screenGui
function GenericScreenGuiProvider:Get(orderName)
	if not RunService:IsRunning() then
		return self:_mockScreenGui(orderName)
	end

	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		error("[GenericScreenGuiProvider] - No localPlayer")
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = String.toCamelCase(orderName)
	screenGui.ResetOnSpawn = false
	screenGui.AutoLocalize = false
	screenGui.DisplayOrder = self:GetDisplayOrder(orderName)
	screenGui.Parent = PlayerGuiUtils.getPlayerGui()
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	return screenGui
end

function GenericScreenGuiProvider:GetDisplayOrder(orderName)
	assert(type(orderName) == "string")
	assert(self._order[orderName], ("No DisplayOrder with orderName '%s'"):format(tostring(orderName)))

	return self._order[orderName]
end

function GenericScreenGuiProvider:SetupMockParent(target)
	assert(not RunService:IsRunning())
	assert(target)

	rawset(self, "_mockParent", target)

	return function()
		if rawget(self, "_mockParent") == target then
			rawset(self, "_mockParent", nil)
		end
	end
end

function GenericScreenGuiProvider:_mockScreenGui(orderName)
	assert(type(orderName) == "string")
	assert(rawget(self, "_mockParent"), "No _mockParent set")

	local displayOrder = self:GetDisplayOrder(orderName)

	local mock = Instance.new("Frame")
	mock.Size = UDim2.new(1, 0, 1, 0)
	mock.BackgroundTransparency = 1
	mock.ZIndex = displayOrder
	mock.Parent = rawget(self, "_mockParent")

	return mock
end

return GenericScreenGuiProvider