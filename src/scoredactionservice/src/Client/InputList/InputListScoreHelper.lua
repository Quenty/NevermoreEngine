--[=[
	Distributes the scored action to the correct providers based upon input mode
	@class InputListScoreHelper
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local InputKeyMapList = require("InputKeyMapList")
local InputKeyMapListUtils = require("InputKeyMapListUtils")
local Rx = require("Rx")
local Set = require("Set")

local InputListScoreHelper = setmetatable({}, BaseObject)
InputListScoreHelper.ClassName = "InputListScoreHelper"
InputListScoreHelper.__index = InputListScoreHelper

function InputListScoreHelper.new(serviceBag, provider, scoredAction, inputKeyMapList)
	local self = setmetatable(BaseObject.new(), InputListScoreHelper)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._provider = assert(provider, "No provider")
	self._scoredAction = assert(scoredAction, "No scoredAction")
	self._inputKeyMapList = assert(inputKeyMapList, "No inputKeyMapList")

	assert(InputKeyMapList.isInputKeyMapList(inputKeyMapList), "Bad inputKeyMapList")

	self._currentTypes = {}

	self._maid:GiveTask(InputKeyMapListUtils.observeActiveInputKeyMap(self._inputKeyMapList, self._serviceBag):Pipe({
		Rx.switchMap(function(activeInputKeyMap)
			if activeInputKeyMap then
				return activeInputKeyMap:ObserveInputTypesList()
			else
				return Rx.of({})
			end
		end)
	}):Subscribe(function(inputTypeList)
		self:_updateInputTypeSet(inputTypeList)
	end))

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

function InputListScoreHelper:_updateInputTypeSet(inputTypeList)
	local remaining = Set.copy(self._currentTypes)

	-- Register inputTypes
	for _, inputType in inputTypeList do
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
	for inputType, _ in remaining do
		self:_unregisterAction(inputType)
	end
end

function InputListScoreHelper:_unregisterAction(inputType)
	if not self.Destroy then
		return
	end

	if not self._currentTypes[inputType] then
		warn("[InputListScoreHelper] - Already unregistered")
	end

	self._currentTypes[inputType] = nil

	if self._provider.Destroy then
		local pickerForType = self._provider:FindPicker(inputType)
		if pickerForType then
			pickerForType:RemoveAction(self._scoredAction)
		else
			warn("No pickerForType was registered. This should not occur.")
		end
	end
end

return InputListScoreHelper