--[=[
	Plugin entry point
]=]

local modules = script:WaitForChild("modules")
local loader = modules:FindFirstChild("LoaderUtils", true).Parent

local require = require(loader).bootstrapPlugin(modules)

local Maid = require("Maid")
local ConverterPane = require("ConverterPane")

local function renderPane(plugin, target)
	local maid = Maid.new()

	local pane = ConverterPane.new()
	maid:GiveTask(pane)

	pane:SetSelected(game.Selection:Get())

	maid:GiveTask(game.Selection.SelectionChanged:Connect(function()
		pane:SetSelected(game.Selection:Get())
	end))

	pane:SetupSettings(plugin)

	maid:GiveTask(pane:Render({
		Parent = target;
	}):Subscribe())

	return maid
end

local function initialize(plugin)
	local maid = Maid.new()
	local toolbar = plugin:CreateToolbar("Object")
	local toggleButton = toolbar:CreateButton(
		"convertButton",
		"Convert UI elements to Blend or Fusion",
		"rbxassetid://8542145374",
		"UI Converter"
	)

	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 0, 0)
	local target = plugin:CreateDockWidgetPluginGui("QuentyUIConverter", info)
	target.Name = "QuentyUIConverter"
	target.Title = "Quenty's UI Converter"
	target.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local function update()
		local enabled = target.Enabled
		toggleButton:SetActive(enabled)

		if enabled then
			maid._current = renderPane(plugin, target)
		else
			maid._current = nil
		end
	end

	maid:GiveTask(toggleButton.Click:Connect(function()
		target.Enabled = not target.Enabled
	end))

	maid:GiveTask(target:GetPropertyChangedSignal("Enabled"):Connect(update))
	update()

	-- clean up self!
	maid:GiveTask(plugin.Unloading:Connect(function()
		maid:DoCleaning()
	end))

	return maid
end

if plugin then
	initialize(plugin)
end