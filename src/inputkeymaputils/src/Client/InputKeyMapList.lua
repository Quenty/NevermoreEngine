--[=[
	An input key map list provides a mapping of input modes to input keys.
	One of these should generally exist per an action with unique bindings.

	All inputs should be bound while this action is active. We can further
	query inputs per an input mode to display only relevant key bindings to
	the user.

	```lua
	local inputKeyMapList = InputKeyMapList.new("BOOST", {
		InputKeyMap.new(INPUT_MODES.KeyboardAndMouse, { Enum.KeyCode.LeftControl });
		InputKeyMap.new(INPUT_MODES.Gamepads, { Enum.KeyCode.ButtonX });
		InputKeyMap.new(INPUT_MODES.Touch, { SlottedTouchButtonUtils.createSlottedTouchButton("primary1") });
	})

	maid:GiveTask(Rx.combineLatest({
		isRobloxTouchButton = inputKeyMapList:ObserveIsRobloxTouchButton();
		inputEnumsList = inputKeyMapList:ObserveInputEnumsList();
	}):Subscribe(function(state)
		maid._contextMaid = nil

		local contextMaid = Maid.new()

		ContextActionService:BindActionAtPriority(
			"MyAction",
			function(_actionName, userInputState, inputObject)
				print("Process input", inputObject)
			end,
			state.isRobloxTouchButton,
			Enum.ContextActionPriority.High.Value,
			unpack(state.inputEnumsList))

			maid._contextMaid = contextMaid
		end))
	end))
	```

	@class InputKeyMapList
]=]

local require = require(script.Parent.loader).load(script)

local InputKeyMap = require("InputKeyMap")
local ObservableMap = require("ObservableMap")
local BaseObject = require("BaseObject")
local InputModeSelector = require("InputModeSelector")
local Observable = require("Observable")
local Maid = require("Maid")
local Rx = require("Rx")
local ObservableCountingMap = require("ObservableCountingMap")
local InputMode = require("InputMode")
local SlottedTouchButtonUtils = require("SlottedTouchButtonUtils")
local RxBrioUtils = require("RxBrioUtils")
local Brio = require("Brio")
local StateStack = require("StateStack")
local InputTypeUtils = require("InputTypeUtils")

local InputKeyMapList = setmetatable({}, BaseObject)
InputKeyMapList.ClassName = "InputKeyMapList"
InputKeyMapList.__index = InputKeyMapList

--[=[
	Constructs a new InputKeyMapList

	@param inputMapName string
	@param inputKeyMapList { InputKeyMap }
	@return InputKeyMapList
]=]
function InputKeyMapList.new(inputMapName, inputKeyMapList)
	local self = setmetatable(BaseObject.new(), InputKeyMapList)

	self._inputKeyMapListName = assert(inputMapName, "No inputMapName")

	self._inputModeToInputKeyMap = ObservableMap.new()
	self._maid:GiveTask(self._inputModeToInputKeyMap)

	for _, inputKeyMap in pairs(inputKeyMapList) do
		self:Add(inputKeyMap)
	end

	return self
end

--[=[
	Returns whether this value is an InputKeyMapList

	@param value any
	@return boolean
]=]
function InputKeyMapList.isInputKeyMapList(value)
	return type(value) == "table" and getmetatable(value) == InputKeyMapList
end

--[=[
	Adds an input key map into the actual list
	@param inputKeyMap InputKeyMap
]=]
function InputKeyMapList:Add(inputKeyMap)
	assert(inputKeyMap, "Bad inputKeyMap")

	self._maid[inputKeyMap:GetInputMode()] = inputKeyMap
	self._inputModeToInputKeyMap:Set(inputKeyMap:GetInputMode(), inputKeyMap)
end

--[=[
	Gets the list name and returns it. Used by an input key map provider
	@return string
]=]
function InputKeyMapList:GetListName()
	return self._inputKeyMapListName
end

function InputKeyMapList:SetInputTypesList(inputMode, inputTypes)
	assert(InputMode.isInputMode(inputMode), "Bad inputMode")
	assert(type(inputTypes) == "table" or inputTypes == nil, "Bad inputTypes")

	if inputTypes == nil then
		self._inputModeToInputKeyMap:Remove(inputMode)
		self._maid[inputMode] = nil
	else
		local inputKeyMap = self._inputModeToInputKeyMap:Get(inputMode)
		if not inputKeyMap then
			self:Add(InputKeyMap.new(inputMode, inputTypes))
		else
			inputKeyMap:SetInputTypesList(inputTypes)
		end
	end
end

--[=[
	Removes the entry for the inputmode

	@param inputMode InputMode
]=]
function InputKeyMapList:RemoveInputMode(inputMode)
	assert(InputMode.isInputMode(inputMode), "Bad inputMode")

	self:SetInputTypesList(inputMode, nil)
end

--[=[
	Observes the input enums list

	@return InputModeSelector
]=]
function InputKeyMapList:GetNewInputModeSelector()
	return InputModeSelector.fromObservableBrio(self:ObserveInputModesBrio())
end

--[=[
	@return Observable<Brio<InputKeyMap>>
]=]
function InputKeyMapList:ObserveInputKeyMapsBrio()
	return self._inputModeToInputKeyMap:ObserveValuesBrio()
end

--[=[
	@return Observable<Brio<InputMode>>
]=]
function InputKeyMapList:ObserveInputModesBrio()
	return self._inputModeToInputKeyMap:ObserveKeysBrio()
end

--[=[
	Observes the input types for the active input map

	@return Observable<InputKeyMap>
]=]
function InputKeyMapList:ObserveActiveInputKeyMap()
	return self:ObserveActiveInputMode():Pipe({
		Rx.switchMap(function(activeInputMode)
			if activeInputMode then
				return self._inputModeToInputKeyMap:ObserveValueForKey(activeInputMode)
			else
				return Rx.of(nil)
			end
		end);
	})
end

--[=[
	Observes the input types for the active input map.

	:::warning
	This should be used for hinting inputs, but it's preferred to
	bind inputs for all modes. See [InputKeyMapList.ObserveInputEnumsList]
	:::

	@return Observable<{ InputType }?>
]=]
function InputKeyMapList:ObserveActiveInputTypesList()
	return self:ObserveActiveInputKeyMap():Pipe({
		Rx.switchMap(function(activeInputMap)
			if activeInputMap then
				return activeInputMap:ObserveInputTypesList()
			else
				return Rx.of(nil)
			end
		end);
		Rx.distinct();
	})
end

--[=[
	Observes the active input mode currently selected.

	@return Observable<InputMode?>
]=]
function InputKeyMapList:ObserveActiveInputMode()
	return Observable.new(function(sub)
		local maid = Maid.new()

		local selector = self:GetNewInputModeSelector()
		maid:GiveTask(selector)

		maid:GiveTask(selector.Changed:Connect(function()
			sub:Fire(selector.Value)
		end))
		sub:Fire(selector.Value)

		return maid
	end)
end

--[=[
	Observes whether the input list includes tapping in the world somewhere.

	@return Observable<boolean>
]=]
function InputKeyMapList:ObserveIsTapInWorld()
	self:_ensureInit()

	return self._isTapInWorld:Observe()
end

--[=[
	Observes whether the input list includes a Roblox button.

	@return Observable<boolean>
]=]
function InputKeyMapList:ObserveIsRobloxTouchButton()
	self:_ensureInit()

	return self._isRobloxTouchButton:Observe()
end

--[=[
	Gets whether the input list includes a Roblox button.

	@return boolean
]=]
function InputKeyMapList:IsRobloxTouchButton()
	self:_ensureInit()

	return self._isRobloxTouchButton:GetState()
end

--[=[
	Gets whether the input list includes a Roblox button.

	@return boolean
]=]
function InputKeyMapList:IsTouchTapInWorld()
	self:_ensureInit()

	return self._isTapInWorld:GetState()
end

--[=[
	Observes the input enums list, which can be used for bindings.

	@return Observable<{UserInputType | KeyCode}>
]=]
function InputKeyMapList:ObserveInputEnumsList()
	self:_ensureInit()

	return self._inputTypesForBinding:ObserveKeysList()
end

--[=[
	Observes the input enums set

	@return Observable<{[UserInputType | KeyCode]: true }>
]=]
function InputKeyMapList:ObserveInputEnumsSet()
	self:_ensureInit()

	return self._inputTypesForBinding:ObserveKeysSet()
end

--[=[
	Observes slotted touch button data in the input modes.

	@return Observable<SlottedTouchButton>
]=]
function InputKeyMapList:ObserveSlottedTouchButtonDataBrio()
	return self._inputModeToInputKeyMap:ObservePairsBrio():Pipe({
		RxBrioUtils.flatMapBrio(function(inputMode, inputKeyMap)
			return inputKeyMap:ObserveInputTypesList():Pipe({
				Rx.switchMap(function(inputTypesList)
					local valid = {}
					for _, inputType in pairs(inputTypesList) do
						if SlottedTouchButtonUtils.isSlottedTouchButton(inputType) then
							local data = SlottedTouchButtonUtils.createTouchButtonData(inputType.slotId, inputMode)
							table.insert(valid, Brio.new(data))
						end
					end

					if not next(valid) then
						return Rx.EMPTY
					else
						return Rx.of(unpack(valid))
					end
				end)
			})
		end);
	})
end

function InputKeyMapList:_ensureInit()
	if self._inputTypesForBinding then
		return self._inputTypesForBinding
	end

	self._inputTypesForBinding = ObservableCountingMap.new()
	self._maid:GiveTask(self._inputTypesForBinding)

	self._isTapInWorld = StateStack.new(false)
	self._maid:GiveTask(self._isTapInWorld)

	self._isRobloxTouchButton = StateStack.new(false)
	self._maid:GiveTask(self._isRobloxTouchButton)

	-- Listen
	self._maid:GiveTask(self._inputModeToInputKeyMap:ObserveValuesBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local inputKeyMapMaid = brio:ToMaid()
		local inputKeyMap = brio:GetValue()

		inputKeyMapMaid:GiveTask(inputKeyMap:ObserveInputTypesList():Subscribe(function(inputTypes)
			local maid = Maid.new()

			for _, inputType in pairs(inputTypes) do
				-- only emit enum items
				if typeof(inputType) == "EnumItem" then
					maid:GiveTask(self._inputTypesForBinding:Add(inputType))
				elseif InputTypeUtils.isTapInWorld(inputType) then
					maid:GiveTask(self._isTapInWorld:PushState(true))
				elseif InputTypeUtils.isRobloxTouchButton(inputType) then
					maid:GiveTask(self._isRobloxTouchButton:PushState(true))
				end
			end

			inputKeyMapMaid._current = maid
		end))
	end))

	return self._inputTypesForBinding
end

return InputKeyMapList