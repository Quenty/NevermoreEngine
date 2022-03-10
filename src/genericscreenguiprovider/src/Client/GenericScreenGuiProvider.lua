--[=[
	Providers screenGuis with a given display order for easy use.

	```lua
	return GenericScreenGuiProvider.new({
	  CLOCK = 5; -- Register layers here
	  BLAH = 8;
	  CHAT = 10;
	})
	```

	In a script that needs a new screen gui, do this:

	```lua
	-- Load your games provider (see above for the registration)
	local screenGuiProvider = require("ScreenGuiProvider")

	-- Yay, you now have a new screen gui
	local screenGui = screenGuiProvider:Get("CLOCK")
	gui.Parent = screenGui
	```

	@class GenericScreenGuiProvider
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local String = require("String")
local PlayerGuiUtils = require("PlayerGuiUtils")
local Blend = require("Blend")

local GenericScreenGuiProvider = {}
GenericScreenGuiProvider.ClassName = GenericScreenGuiProvider

--[=[
	Constructs a new screen gui provider.
	@param orders { [string]: number }
	@return GenericScreenGuiProvider
]=]
function GenericScreenGuiProvider.new(orders)
	assert(type(orders) == "table", "Bad orders")

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

function GenericScreenGuiProvider:__newindex(index, _)
	error(("Bad index %q"):format(tostring(index)), 2)
end

--[=[
	Returns a blend ScreenGui.
	@param orderName string
	@return Observable<Instance>
]=]
function GenericScreenGuiProvider:ObserveScreenGui(orderName)
	if not RunService:IsRunning() then
		return self:_observeMockScreenGui(orderName)
	end

	return Blend.New "ScreenGui" {
		Name = String.toCamelCase(orderName);
		ResetOnSpawn = false;
		AutoLocalize = false;
		DisplayOrder = self:GetDisplayOrder(orderName);
		Parent = PlayerGuiUtils.getPlayerGui();
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
	}
end

--[=[
	Returns a new ScreenGui at DisplayOrder specified
	@param orderName string -- Order name of display order
	@return ScreenGui
]=]
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

--[=[
	Retrieve the display order for a given order.
	@param orderName string -- Order name of display order
	@return number
]=]
function GenericScreenGuiProvider:GetDisplayOrder(orderName)
	assert(type(orderName) == "string", "Bad orderName")
	assert(self._order[orderName], ("No DisplayOrder with orderName '%s'"):format(tostring(orderName)))

	return self._order[orderName]
end

--[=[
	Sets up a mock parent for the given target during test mode.
	@param target GuiBase
	@return function -- Cleanup function to reset mock parent
]=]
function GenericScreenGuiProvider:SetupMockParent(target)
	assert(not RunService:IsRunning(), "Bad target")
	assert(target, "Bad target")

	rawset(self, "_mockParent", target)

	return function()
		if rawget(self, "_mockParent") == target then
			rawset(self, "_mockParent", nil)
		end
	end
end

function GenericScreenGuiProvider:_mockScreenGui(orderName)
	assert(type(orderName) == "string", "Bad orderName")
	assert(rawget(self, "_mockParent"), "No _mockParent set")

	local displayOrder = self:GetDisplayOrder(orderName)

	local mock = Instance.new("Frame")
	mock.Size = UDim2.new(1, 0, 1, 0)
	mock.BackgroundTransparency = 1
	mock.ZIndex = displayOrder
	mock.Parent = rawget(self, "_mockParent")

	return mock
end

function GenericScreenGuiProvider:_observeMockScreenGui(orderName)
	assert(type(orderName) == "string", "Bad orderName")
	assert(rawget(self, "_mockParent"), "No _mockParent set")

	local displayOrder = self:GetDisplayOrder(orderName)

	return Blend.New "Frame" {
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		ZIndex = displayOrder;
		Parent = rawget(self, "_mockParent");
	};
end



return GenericScreenGuiProvider