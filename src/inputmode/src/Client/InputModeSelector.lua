--[=[
	Selects the most recent input mode and attempts to identify the best state from it.
	@class InputModeSelector
]=]

local require = require(script.Parent.loader).load(script)

local INPUT_MODES = require("INPUT_MODES")
local Maid = require("Maid")
local ValueObject = require("ValueObject")

local InputModeSelector = {}
InputModeSelector.ClassName = "InputModeSelector"
InputModeSelector.DEFAULT_MODES = {
	INPUT_MODES.Gamepads,
	INPUT_MODES.Keyboard,
	INPUT_MODES.Touch
}

--[=[
	Constructs a new InputModeSelector
	@param inputModes { InputMode }
	@return InputModeSelector
]=]
function InputModeSelector.new(inputModes)
	local self = setmetatable({}, InputModeSelector)

	self._maid = Maid.new()

	self._activeMode = ValueObject.new()
	self._maid:GiveTask(self._activeMode)

--[=[
	Event that fires whenever the active mode changes.
	@prop Changed Signal<InputMode, InputMode> -- newMode, oldMode
	@within InputModeSelector
]=]
	self.Changed = self._activeMode.Changed

	for _, inputMode in pairs(inputModes or InputModeSelector.DEFAULT_MODES) do
		self:_addInputMode(inputMode)
	end

	return self
end

--[=[
	Returns the current active mode
	@return InputMode
]=]
function InputModeSelector:GetActiveMode()
	return rawget(self, "_activeMode").Value
end

--[=[
	The current active input mode
	@prop Value InputMode?
	@within InputModeSelector
]=]
function InputModeSelector:__index(index)
	if index == "Value" then
		return rawget(self, "_activeMode").Value
	elseif InputModeSelector[index] then
		return InputModeSelector[index]
	else
		local value = rawget(self, index)
		if value then
			return value
		else
			error(("[InputModeSelector] - Bad index '%s'"):format(tostring(index)))
		end
	end
end

--[=[
	Binds the updateBindFunction to the mode selector

	```lua
	local inputModeSelector = InputModeSelector.new({
		INPUT_MODES.Mouse;
		INPUT_MODES.Touch;
	})

	inputModeSelector:Bind(function(inputMode)
		if inputMode == INPUT_MODES.Mouse then
			print("Show mouse input hints")
		elseif inputMode == INPUT_MODES.Touch then
			print("Show touch input hints")
		else
			-- Unknown input mode
			warn("Unknown input mode") -- should not occur
		end
	end)
	```

	@param updateBindFunction (newMode: InputMode, modeMaid: Maid) -> ()
	@return InputModeSelector
]=]
function InputModeSelector:Bind(updateBindFunction)
	local maid = Maid.new()
	self._maid[updateBindFunction] = maid

	local function onChange(newMode, _)
		maid._modeMaid = nil

		if newMode then
			local modeMaid = Maid.new()
			maid._modeMaid = modeMaid
			updateBindFunction(newMode, modeMaid)
		end
	end

	maid:GiveTask(self._activeMode.Changed:Connect(onChange))
	onChange(self._activeMode.Value, nil)

	return self
end

function InputModeSelector:_addInputMode(inputMode)
	assert(not self._maid[inputMode], "Bad inputMode")

	self._maid[inputMode] = inputMode.Enabled:Connect(function()
		self._activeMode.Value = inputMode
	end)

	if not self._activeMode.Value
		or inputMode:GetLastEnabledTime() > self._activeMode.Value:GetLastEnabledTime() then
		self._activeMode.Value = inputMode
	end
end

--[=[
	Cleans up the input mode selector.

	:::info
	This should be called whenever the mode selector is done being used.
	:::
]=]
function InputModeSelector:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return InputModeSelector