--[=[
	Centralizes input of keys. You can construct a new provider in a
	package and key bindings can be recovered from it. This is designed
	for user configuration/rebindings.

	```lua
	local inputMapProvider = InputKeyMapListProvider.new("General", function(self)
		self:Add(InputKeyMapList.new("JUMP", {
			InputKeyMap.new(INPUT_MODES.KeyboardAndMouse, { Enum.KeyCode.Space });
			InputKeyMap.new(INPUT_MODES.Gamepads, { Enum.KeyCode.ButtonA });
			InputKeyMap.new(INPUT_MODES.Touch, { SlottedTouchButtonUtils.createSlottedTouchButton("primary3") });
		}))
		self:Add(InputKeyMapList.new("HONK", {
			InputKeyMap.new(INPUT_MODES.KeyboardAndMouse, { Enum.KeyCode.H });
			InputKeyMap.new(INPUT_MODES.Gamepads, { Enum.KeyCode.DPadUp });
			InputKeyMap.new(INPUT_MODES.Touch, { SlottedTouchButtonUtils.createSlottedTouchButton("primary2") });
		}))
		self:Add(InputKeyMapList.new("BOOST", {
			InputKeyMap.new(INPUT_MODES.KeyboardAndMouse, { Enum.KeyCode.LeftControl });
			InputKeyMap.new(INPUT_MODES.Gamepads, { Enum.KeyCode.ButtonX });
			InputKeyMap.new(INPUT_MODES.Touch, { SlottedTouchButtonUtils.createSlottedTouchButton("primary4") });
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
local InputKeyMapServiceClient = require("InputKeyMapServiceClient")

local InputKeyMapListProvider = {}
InputKeyMapListProvider.ClassName = "InputKeyMapListProvider"
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
	self._createDefaults = assert(createDefaults, "No createDefaults")

	return self
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

	if not self._inputKeyMapLists then
		if not RunService:IsRunning() then
			-- Test mode initialize
			self._maid = Maid.new()
			self:_ensureDefaultsInit()
		else
			error("Not initialized, make sure to retrieve via serviceBag and init")
		end
	end

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
end

function InputKeyMapListProvider:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._serviceBag:GetService(InputKeyMapServiceClient):RegisterProvider(self)
	self._maid = Maid.new()

	self:_ensureDefaultsInit()
end

function InputKeyMapListProvider:_ensureDefaultsInit()
	if not self._inputKeyMapLists then
		self._inputKeyMapLists = {}

		self._createDefaults(self, self._serviceBag)
	end
end

function InputKeyMapListProvider:Start()
	-- empty function
end

function InputKeyMapListProvider:Destroy()
	if self._maid then
		self._maid:DoCleaning()
		self._maid = nil
	end

	self._inputKeyMapLists = nil
end

return InputKeyMapListProvider