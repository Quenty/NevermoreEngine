--!strict
--[=[
	An input key map list provides a mapping of input modes to input keys.
	One of these should generally exist per an action with unique bindings.

	All inputs should be bound while this action is active. We can further
	query inputs per an input mode to display only relevant key bindings to
	the user.

	```lua
	local inputKeyMapList = InputKeyMapList.new("BOOST", {
		InputKeyMap.new(InputModeTypes.KeyboardAndMouse, { Enum.KeyCode.LeftControl });
		InputKeyMap.new(InputModeTypes.Gamepads, { Enum.KeyCode.ButtonX });
		InputKeyMap.new(InputModeTypes.Touch, { SlottedTouchButtonUtils.createSlottedTouchButton("primary1") });
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

local BaseObject = require("BaseObject")
local Brio = require("Brio")
local DuckTypeUtils = require("DuckTypeUtils")
local InputChordUtils = require("InputChordUtils")
local InputKeyMap = require("InputKeyMap")
local InputModeType = require("InputModeType")
local InputModeTypes = require("InputModeTypes")
local InputTypeUtils = require("InputTypeUtils")
local Maid = require("Maid")
local ObservableCountingMap = require("ObservableCountingMap")
local ObservableMap = require("ObservableMap")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local SlottedTouchButtonUtils = (require :: any)("SlottedTouchButtonUtils")
local StateStack = require("StateStack")
local String = require("String")
local _Observable = require("Observable")
local _Brio = require("Brio")
local _Set = require("Set")

local InputKeyMapList = setmetatable({}, BaseObject)
InputKeyMapList.ClassName = "InputKeyMapList"
InputKeyMapList.__index = InputKeyMapList

export type InputKeyMapList = typeof(setmetatable(
	{} :: {
		_inputKeyMapListName: string,
		_inputModeTypeToInputKeyMap: any, -- ObservableMap.ObservableMap<InputModeType.InputModeType, InputKeyMap.InputKeyMap>,
		_inputTypesForBinding: any, -- ObservableCountingMap.ObservableCountingMap<InputTypeUtils.InputType>,
		_isTapInWorld: StateStack.StateStack<boolean>,
		_isRobloxTouchButton: StateStack.StateStack<boolean>,
		_options: InputKeyMapListOptions,
	},
	{} :: typeof({ __index = InputKeyMapList })
)) & BaseObject.BaseObject

export type InputKeyMapListOptions = {
	bindingName: string,
	rebindable: boolean,
}

--[=[
	Constructs a new InputKeyMapList

	@param inputMapName string
	@param inputKeyMapList { InputKeyMap }
	@param options { bindingName: string, rebindable: boolean } -- configuration options
	@return InputKeyMapList
]=]
function InputKeyMapList.new(
	inputMapName: string,
	inputKeyMapList: { InputKeyMap.InputKeyMap },
	options: InputKeyMapListOptions
): InputKeyMapList
	local self = setmetatable(BaseObject.new() :: any, InputKeyMapList)

	self._inputKeyMapListName = assert(inputMapName, "No inputMapName")
	self._options = assert(options, "No options")

	self._inputModeTypeToInputKeyMap = self._maid:Add(ObservableMap.new())

	for _, inputKeyMap in inputKeyMapList do
		self:Add(inputKeyMap)
	end

	return self
end

--[=[
	Constructs a new InputKeyMapList from specific keys

	```
	local inputKeyMapList = InputKeyMapList.fromInputKeys({ Enum.KeyCode.E })
	```

	@param inputKeys { any }
	@param options { bindingName: string, rebindable: boolean }? -- Optional configuration options
	@return InputKeyMapList
]=]
function InputKeyMapList.fromInputKeys(
	inputKeys: { InputModeType.InputModeKey },
	options: InputKeyMapListOptions?
): InputKeyMapList
	assert(type(inputKeys) == "table", "Bad inputKeys")

	local self: InputKeyMapList = InputKeyMapList.new("generated", {}, options or {
		rebindable = false,
		bindingName = "generated",
	})

	local INPUT_TYPES = {
		InputModeTypes.KeyboardAndMouse,
		InputModeTypes.Gamepads,
		InputModeTypes.Touch,
	}

	for _, inputModeType in INPUT_TYPES do
		local inputTypes = {}
		for _, item in inputKeys do
			if inputModeType:IsValid(item) then
				table.insert(inputTypes, item)
			end
		end

		-- Adding it ensures clean up
		self:Add(InputKeyMap.new(inputModeType, inputTypes))
	end

	return self
end

--[=[
	Returns whether this value is an InputKeyMapList

	@param value any
	@return boolean
]=]
function InputKeyMapList.isInputKeyMapList(value: any): boolean
	return DuckTypeUtils.isImplementation(InputKeyMapList, value)
end

--[=[
	Returns user bindable time
	@return boolean
]=]
function InputKeyMapList.IsUserRebindable(self: InputKeyMapList): boolean
	return self._options.rebindable == true
end

--[=[
	Gets the english name
	@return string
]=]
function InputKeyMapList.GetBindingName(self: InputKeyMapList): string
	return self._options.bindingName
end

function InputKeyMapList.GetBindingTranslationKey(self: InputKeyMapList): string
	return "keybinds." .. String.toCamelCase(self._inputKeyMapListName)
end

--[=[
	Adds an input key map into the actual list
	@param inputKeyMap InputKeyMap
]=]
function InputKeyMapList.Add(self: InputKeyMapList, inputKeyMap: InputKeyMap.InputKeyMap): ()
	assert(inputKeyMap, "Bad inputKeyMap")

	self._maid[inputKeyMap:GetInputModeType()] = inputKeyMap
	self._inputModeTypeToInputKeyMap:Set(inputKeyMap:GetInputModeType(), inputKeyMap)
end

--[=[
	Gets the list name and returns it. Used by an input key map provider
	@return string
]=]
function InputKeyMapList.GetListName(self: InputKeyMapList): string
	return self._inputKeyMapListName
end

function InputKeyMapList.SetInputTypesList(
	self: InputKeyMapList,
	inputModeType: InputModeType.InputModeType,
	inputTypes
): ()
	assert(InputModeType.isInputModeType(inputModeType), "Bad inputModeType")
	assert(type(inputTypes) == "table" or inputTypes == nil, "Bad inputTypes")

	if inputTypes == nil then
		self._inputModeTypeToInputKeyMap:Remove(inputModeType)
		self._maid[inputModeType] = nil
	else
		local inputKeyMap = self._inputModeTypeToInputKeyMap:Get(inputModeType)
		if not inputKeyMap then
			self:Add(InputKeyMap.new(inputModeType, inputTypes))
		else
			inputKeyMap:SetInputTypesList(inputTypes)
		end
	end
end

function InputKeyMapList.SetDefaultInputTypesList(
	self: InputKeyMapList,
	inputModeType: InputModeType.InputModeType,
	inputTypes
): ()
	assert(InputModeType.isInputModeType(inputModeType), "Bad inputModeType")
	assert(type(inputTypes) == "table" or inputTypes == nil, "Bad inputTypes")

	if inputTypes == nil then
		self._inputModeTypeToInputKeyMap:Remove(inputModeType)
		self._maid[inputModeType] = nil
	else
		local inputKeyMap = self._inputModeTypeToInputKeyMap:Get(inputModeType)
		if not inputKeyMap then
			self:Add(InputKeyMap.new(inputModeType, inputTypes))
		else
			inputKeyMap:SetDefaultInputTypesList(inputTypes)
		end
	end
end

--[=[
	Gets the input types list for this input key map

	@param inputModeType InputModeType
	@return { InputType }
]=]
function InputKeyMapList.GetInputTypesList(
	self: InputKeyMapList,
	inputModeType: InputModeType.InputModeType
): { InputTypeUtils.InputType }
	local inputKeyMap: InputKeyMap.InputKeyMap = self._inputModeTypeToInputKeyMap:Get(inputModeType)
	if inputKeyMap then
		return inputKeyMap:GetInputTypesList()
	else
		return {}
	end
end

--[=[
	Gets the input key maps list

	@return { InputKeyMap }
]=]
function InputKeyMapList:GetInputKeyMaps(): { InputKeyMap.InputKeyMap }
	return self._inputModeTypeToInputKeyMap:GetValueList()
end

--[=[
	Gets the default input types list for this input key map

	@param inputModeType InputModeType
	@return { InputType }
]=]
function InputKeyMapList.GetDefaultInputTypesList(
	self: InputKeyMapList,
	inputModeType: InputModeType.InputModeType
): { InputTypeUtils.InputType }
	local inputKeyMap = self._inputModeTypeToInputKeyMap:Get(inputModeType)
	if inputKeyMap then
		return inputKeyMap:GetDefaultInputTypesList()
	else
		return {}
	end
end

--[=[
	Observes a brio with the first value as the InputModeType and the second value as the KeyMapList
	@return Observable<Brio<InputModeType, InputKeyMap>>
]=]
function InputKeyMapList.ObservePairsBrio(self: InputKeyMapList): _Observable.Observable<
	_Brio.Brio<InputModeType.InputModeType, InputKeyMap.InputKeyMap>
>
	return self._inputModeTypeToInputKeyMap:ObservePairsBrio()
end

--[=[
	Restores the default value for all lists
]=]
function InputKeyMapList.RestoreDefault(self: InputKeyMapList): ()
	for _, item in self._inputModeTypeToInputKeyMap:GetValueList() do
		item:RestoreDefault()
	end
end

--[=[
	Removes the entry for the inputmodeType

	@param inputModeType InputModeType
]=]
function InputKeyMapList.RemoveInputModeType(self: InputKeyMapList, inputModeType: InputModeType.InputModeType): ()
	assert(InputModeType.isInputModeType(inputModeType), "Bad inputModeType")

	self:SetInputTypesList(inputModeType, nil)
end

--[=[
	@return Observable<Brio<InputKeyMap>>
]=]
function InputKeyMapList.ObserveInputKeyMapsBrio(
	self: InputKeyMapList
): _Observable.Observable<_Brio.Brio<InputKeyMap.InputKeyMap>>
	return self._inputModeTypeToInputKeyMap:ObserveValuesBrio()
end

--[=[
	@return Observable<Brio<InputModeType>>
]=]
function InputKeyMapList.ObserveInputModesTypesBrio(
	self: InputKeyMapList
): _Observable.Observable<_Brio.Brio<InputModeType.InputModeType>>
	return self._inputModeTypeToInputKeyMap:ObserveKeysBrio()
end

--[=[
	Observes the input types for the active input map

	@param inputModeType InputModeType
	@return Observable<InputKeyMap?>
]=]
function InputKeyMapList.ObserveInputKeyMapForInputMode(
	self: InputKeyMapList,
	inputModeType: InputModeType.InputModeType
): _Observable.Observable<InputKeyMap.InputKeyMap?>
	assert(InputModeType.isInputModeType(inputModeType), "Bad inputModeType")

	return self._inputModeTypeToInputKeyMap:ObserveValueForKey(inputModeType)
end

--[=[
	Observes whether the input list includes tapping in the world somewhere.

	@return Observable<boolean>
]=]
function InputKeyMapList.ObserveIsTapInWorld(self: InputKeyMapList): _Observable.Observable<boolean>
	self:_ensureInit()

	return self._isTapInWorld:Observe()
end

--[=[
	Observes whether the input list includes a Roblox button.

	@return Observable<boolean>
]=]
function InputKeyMapList.ObserveIsRobloxTouchButton(self: InputKeyMapList)
	self:_ensureInit()

	return self._isRobloxTouchButton:Observe()
end

--[=[
	Gets whether the input list includes a Roblox button.

	@return boolean
]=]
function InputKeyMapList.IsRobloxTouchButton(self: InputKeyMapList): boolean
	self:_ensureInit()

	return self._isRobloxTouchButton:GetState()
end

--[=[
	Gets whether the input list includes a Roblox button.

	@return boolean
]=]
function InputKeyMapList.IsTouchTapInWorld(self: InputKeyMapList): boolean
	self:_ensureInit()

	return self._isTapInWorld:GetState()
end

--[=[
	Observes the input enums list, which can be used for bindings.

	@return Observable<{UserInputType | KeyCode}>
]=]
function InputKeyMapList.ObserveInputEnumsList(
	self: InputKeyMapList
): _Observable.Observable<{ InputTypeUtils.InputType }>
	self:_ensureInit()

	return self._inputTypesForBinding:ObserveKeysList()
end

--[=[
	Gets the input enums list, which can be used for bindings.

	@return {UserInputType | KeyCode}
]=]
function InputKeyMapList.GetInputEnumsList(self: InputKeyMapList): { InputTypeUtils.InputType }
	self:_ensureInit()

	return self._inputTypesForBinding:GetKeyList()
end

--[=[
	Observes the input enums set

	@return Observable<{[UserInputType | KeyCode]: true }>
]=]
function InputKeyMapList.ObserveInputEnumsSet(
	self: InputKeyMapList
): _Observable.Observable<_Set.Set<InputTypeUtils.InputType>>
	self:_ensureInit()

	return self._inputTypesForBinding:ObserveKeysSet()
end

--[=[
	Observes slotted touch button data in the input modes.

	@return Observable<SlottedTouchButton>
]=]
function InputKeyMapList.ObserveSlottedTouchButtonDataBrio(self: InputKeyMapList)
	return self._inputModeTypeToInputKeyMap:ObservePairsBrio():Pipe({
		RxBrioUtils.flatMapBrio(function(inputModeType, inputKeyMap)
			return inputKeyMap:ObserveInputTypesList():Pipe({
				Rx.switchMap(function(inputTypesList: { InputTypeUtils.InputType }): any
					local valid = {}
					for _, inputType in inputTypesList do
						if SlottedTouchButtonUtils.isSlottedTouchButton(inputType) then
							local data =
								SlottedTouchButtonUtils.createTouchButtonData((inputType :: any).slotId, inputModeType)
							table.insert(valid, Brio.new(data))
						end
					end

					if not next(valid) then
						return Rx.EMPTY
					else
						return Rx.of(unpack(valid))
					end
				end),
			})
		end),
	})
end

function InputKeyMapList.GetModifierChords(_self: InputKeyMapList, _inputEnumType)
	-- TODO: Provide way to query modifer chords
	return {}
end

function InputKeyMapList._ensureInit(self: InputKeyMapList)
	if self._inputTypesForBinding then
		return self._inputTypesForBinding
	end

	local countingMap: ObservableCountingMap.ObservableCountingMap<InputTypeUtils.InputType> =
		self._maid:Add(ObservableCountingMap.new()) :: any
	self._inputTypesForBinding = countingMap
	self._isTapInWorld = self._maid:Add(StateStack.new(false, "boolean"))
	self._isRobloxTouchButton = self._maid:Add(StateStack.new(false, "boolean"))

	-- Listen
	self._maid:GiveTask(self._inputModeTypeToInputKeyMap:ObserveValuesBrio():Subscribe(function(brio: Brio.Brio<InputKeyMap.InputKeyMap>)
		if brio:IsDead() then
			return
		end

		local inputKeyMapMaid = brio:ToMaid()
		local inputKeyMap: InputKeyMap.InputKeyMap = brio:GetValue()

		inputKeyMapMaid:GiveTask(inputKeyMap:ObserveInputTypesList():Subscribe(function(inputTypes)
			local maid = Maid.new()

			for _, inputType in inputTypes do
				-- only emit enum items
				if typeof(inputType) == "EnumItem" then
					maid:GiveTask(countingMap:Add(inputType :: any))
				elseif InputTypeUtils.isTapInWorld(inputType) then
					maid:GiveTask(self._isTapInWorld:PushState(true))
				elseif InputTypeUtils.isRobloxTouchButton(inputType) then
					maid:GiveTask(self._isRobloxTouchButton:PushState(true))
				elseif InputChordUtils.isModifierInputChord(inputType) then
					maid:GiveTask(countingMap:Add((inputType :: any).keyCode))
				end
			end

			inputKeyMapMaid._current = maid
		end))
	end))

	return self._inputTypesForBinding
end

return InputKeyMapList