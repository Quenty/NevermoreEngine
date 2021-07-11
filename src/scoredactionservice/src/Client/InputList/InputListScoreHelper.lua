--- Distributes the scored action to the correct providers based upon input mode
-- @classmod InputListScoreHelper
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local InputKeyMapUtils = require("InputKeyMapUtils")
local InputModeSelector = require("InputModeSelector")
local Set = require("Set")

local InputListScoreHelper = setmetatable({}, BaseObject)
InputListScoreHelper.ClassName = "InputListScoreHelper"
InputListScoreHelper.__index = InputListScoreHelper

function InputListScoreHelper.new(provider, scoredAction, inputKeyMapList)
	local self = setmetatable(BaseObject.new(), InputListScoreHelper)

	self._provider = assert(provider, "No provider")
	self._scoredAction = assert(scoredAction, "No scoredAction")
	self._inputKeyMapList = assert(inputKeyMapList, "No inputKeyMapList")

	self._currentTypes = {}

	self._modeSelector = InputModeSelector.new(InputKeyMapUtils.getInputModes(inputKeyMapList))
	self._maid:GiveTask(self._modeSelector)

	self._maid:GiveTask(self._modeSelector.Changed:Connect(function()
		self:_handleModeChanged()
	end))
	self:_handleModeChanged()

	self._maid:GiveTask(function()
		local current, _ = next(self._currentTypes)
		while current do
			self:_unregisterAction(current)

			-- Paranoid nil to prevent infinite loop
			self._currentTypes[current] = nil
			current, _ = next(self._currentTypes)
		end
	end)

	return self
end

function InputListScoreHelper:_handleModeChanged()
	local currentMode = self._modeSelector:GetActiveMode()
	local inputTypeSet = InputKeyMapUtils.getInputTypeSetForMode(self._inputKeyMapList, currentMode)

	local remaining = Set.copy(self._currentTypes)

	-- Register inputTypes
	for inputType, _ in pairs(inputTypeSet) do
		if not self._currentTypes[inputType] then
			self._currentTypes[inputType] = true

			-- This works pretty ok, but there's no communication between
			-- inputType -> inputType, so we might get a conflict in mapping
			-- with 2 types, if there are multiple options per a mode.
			local pickerForType = self._provider:GetOrCreatePicker(inputType)
			pickerForType:AddAction(self._scoredAction)
		end

		remaining[inputType] = nil
	end

	-- Unregister old types
	for inputType, _ in pairs(remaining) do
		self:_unregisterAction(inputType)
	end

	self._currentTypes = inputTypeSet
end

function InputListScoreHelper:_unregisterAction(inputType)
	if not self._currentTypes[inputType] then
		warn("[InputListScoreHelper] - Already unregistered")
	end

	self._currentTypes[inputType] = nil

	local pickerForType = self._provider:FindPicker(inputType)
	if pickerForType then
		pickerForType:RemoveAction(self._scoredAction)
	else
		warn("No pickerForType was registered. This should not occur.")
	end
end

return InputListScoreHelper