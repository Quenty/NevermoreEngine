-- Selects the most recent input mode and attempts to
-- identify the best state from it
-- @classmod InputModeSelector

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local INPUT_MODES = require("INPUT_MODES")
local Maid = require("Maid")
local ValueObject = require("ValueObject")

local InputModeSelector = {}
InputModeSelector.ClassName = "InputModeSelector"
InputModeSelector.INPUT_MODES = INPUT_MODES
InputModeSelector.DEFAULT_MODES = {
	INPUT_MODES.Gamepads,
	INPUT_MODES.Keyboard,
	INPUT_MODES.Touch
}

function InputModeSelector.new(inputModes)
	local self = setmetatable({}, InputModeSelector)

	self._maid = Maid.new()

	self._activeMode = ValueObject.new()
	self.Changed = self._activeMode.Changed

	self._maid:GiveTask(self._activeMode)

	for _, inputMode in pairs(inputModes or InputModeSelector.DEFAULT_MODES) do
		self:_addInputMode(inputMode)
	end

	return self
end

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

function InputModeSelector:Bind(updateBindFunction)
	local maid = Maid.new()
	self._maid[updateBindFunction] = maid

	local function onChange(newMode, oldMode)
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
	assert(not self._maid[inputMode])

	self._maid[inputMode] = inputMode.Enabled:Connect(function()
		self._activeMode.Value = inputMode
	end)

	if not self._activeMode.Value then
		self._activeMode.Value = inputMode
	elseif inputMode:GetLastEnabledTime() > self._activeMode.Value:GetLastEnabledTime() then
		self._activeMode.Value = inputMode
	end
end

function InputModeSelector:Destroy()
	self._maid:DoCleaning()
end

return InputModeSelector