--[=[
	Centralizes input of keys. You can construct a new provider in a
	package and key bindings can be recovered from it. This is designed
	for user configuration/rebindings.

	```lua
	local inputMapProvider = InputKeyMapListProvider.new("General", function(self)
		self:Add(InputKeyMapList.new("JUMP", {
			InputKeyMap.new(InputModeTypes.KeyboardAndMouse, { Enum.KeyCode.Space });
			InputKeyMap.new(InputModeTypes.Gamepads, { Enum.KeyCode.ButtonA });
			InputKeyMap.new(InputModeTypes.Touch, { SlottedTouchButtonUtils.createSlottedTouchButton("primary3") });
		}, {
			bindingName = "Jump";
			rebindable = true;
		}))
		self:Add(InputKeyMapList.new("HONK", {
			InputKeyMap.new(InputModeTypes.KeyboardAndMouse, { Enum.KeyCode.H });
			InputKeyMap.new(InputModeTypes.Gamepads, { Enum.KeyCode.DPadUp });
			InputKeyMap.new(InputModeTypes.Touch, { SlottedTouchButtonUtils.createSlottedTouchButton("primary2") });
		}, {
			bindingName = "Honk";
			rebindable = true;
		}))
		self:Add(InputKeyMapList.new("BOOST", {
			InputKeyMap.new(InputModeTypes.KeyboardAndMouse, { Enum.KeyCode.LeftControl });
			InputKeyMap.new(InputModeTypes.Gamepads, { Enum.KeyCode.ButtonX });
			InputKeyMap.new(InputModeTypes.Touch, { SlottedTouchButtonUtils.createSlottedTouchButton("primary4") });
		}, {
			bindingName = "Boost";
			rebindable = true;
		}))
	end)

	local inputMap = serviceBag:GetService(inputMapProvider)

	serviceBag:Init()
	serviceBag:Start()
	```

	@class InputKeyMapListProvider
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Maid = require("Maid")
local InputKeyMapRegistryServiceShared = require("InputKeyMapRegistryServiceShared")
local ObservableList = require("ObservableList")

local InputKeyMapListProvider = {}
InputKeyMapListProvider.ClassName = "InputKeyMapListProvider"
InputKeyMapListProvider.ServiceName = "InputKeyMapListProvider"
InputKeyMapListProvider.__index = InputKeyMapListProvider

--[=[
	Constructs a new InputKeyMapListProvider. The name will be used for retrieval,
	for example, if the dialog system needs to get a general input hint to show
	to the user.

	@param providerName string -- Name to use for global specification.
	@param createDefaults callback -- Callback to construct the default items on init
	@return InputKeyMapList
]=]
function InputKeyMapListProvider.new(providerName, createDefaults)
	local self = setmetatable({}, InputKeyMapListProvider)

	self._providerName = assert(providerName, "No providerName")
	self.ServiceName = providerName
	self._createDefaults = assert(createDefaults, "No createDefaults")

	return self
end

function InputKeyMapListProvider:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self:_ensureDefaultsInit()

	-- Only register after initialization
	self._maid:GiveTask(self._serviceBag:GetService(InputKeyMapRegistryServiceShared):RegisterProvider(self))
end

function InputKeyMapListProvider:Start()
	-- empty function
end

--[=[
	Gets this providers name
	@return string
]=]
function InputKeyMapListProvider:GetProviderName()
	return self._providerName
end

--[=[
	Gets an input key map list for the given name. Errors if it is not
	defined.

	@param keyMapListName string
	@return InputKeyMapList
]=]
function InputKeyMapListProvider:GetInputKeyMapList(keyMapListName)
	local keyMapList = self:FindInputKeyMapList(keyMapListName)
	if not keyMapList then
		error(("Bad keyMapListName %q"):format(tostring(keyMapListName)))
	end

	return keyMapList
end

--[=[
	Finds an input key map list for the given name
	@param keyMapListName string
	@return InputKeyMapList
]=]
function InputKeyMapListProvider:FindInputKeyMapList(keyMapListName)
	assert(type(keyMapListName) == "string", "Bad keyMapListName")

	if RunService:IsRunning() and not self._inputKeyMapLists then
		error("Not initialized, make sure to retrieve via serviceBag and init")
	end

	-- Test mode initialize
	if not self._inputKeyMapLists then
		self._maid = Maid.new()
	end

	self:_ensureDefaultsInit()

	return self._inputKeyMapLists[keyMapListName]
end

function InputKeyMapListProvider:Add(inputKeyMapList)
	assert(inputKeyMapList, "Bad inputKeyMapList")
	assert(self._maid, "Not initialized")

	if self._inputKeyMapLists[inputKeyMapList:GetListName()] then
		error(("Already added %q"):format(inputKeyMapList:GetListName()))
	end

	self._inputKeyMapLists[inputKeyMapList:GetListName()] = inputKeyMapList
	self._maid:GiveTask(inputKeyMapList)

	self._maid:GiveTask(self._inputMapLists:Add(inputKeyMapList))
end

function InputKeyMapListProvider:ObserveInputKeyMapListsBrio()
	return self._inputMapLists:ObserveItemsBrio()
end

function InputKeyMapListProvider:_ensureDefaultsInit()
	if not self._inputKeyMapLists then
		self._inputMapLists = ObservableList.new()
		self._maid:GiveTask(self._inputMapLists)

		self._inputKeyMapLists = {}

		self._createDefaults(self, self._serviceBag)
	end
end

function InputKeyMapListProvider:Destroy()
	if self._maid then
		self._maid:DoCleaning()
		self._maid = nil
	end

	self._inputKeyMapLists = nil
end

return InputKeyMapListProvider