--!strict
--[=[
	Selects the most recent input mode and attempts to identify the best state from it.
	@class InputModeTypeSelector
]=]

local require = require(script.Parent.loader).load(script)

local InputModeTypes = require("InputModeTypes")
local Maid = require("Maid")
local ValueObject = require("ValueObject")
local InputModeServiceClient = require("InputModeServiceClient")
local ServiceBag = require("ServiceBag")
local Rx = require("Rx")
local InputModeType = require("InputModeType")
local _Observable = require("Observable")
local _Signal = require("Signal")
local _Brio = require("Brio")

local InputModeTypeSelector = {}
InputModeTypeSelector.ClassName = "InputModeTypeSelector"
InputModeTypeSelector.DEFAULT_MODE_TYPES = {
	InputModeTypes.Gamepads,
	InputModeTypes.Keyboard,
	InputModeTypes.Touch,
} :: { InputModeType.InputModeType }

export type InputModeTypeSelector = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_inputModeTypeList: { InputModeType.InputModeType },
		_activeModeType: ValueObject.ValueObject<InputModeType.InputModeType>,
		_serviceBag: ServiceBag.ServiceBag,
		_inputModeServiceClient: InputModeServiceClient.InputModeServiceClient,

		Value: InputModeType.InputModeType?,
		Changed: _Signal.Signal<InputModeType.InputModeType, InputModeType.InputModeType>,
	},
	{} :: typeof({ __index = InputModeTypeSelector })
))

--[=[
	Constructs a new InputModeTypeSelector

	@param serviceBag ServiceBag
	@param inputModesTypes { InputModeType }
	@return InputModeTypeSelector
]=]
function InputModeTypeSelector.new(
	serviceBag: ServiceBag.ServiceBag,
	inputModesTypes: { InputModeType.InputModeType }
): InputModeTypeSelector
	local self: any = setmetatable({}, InputModeTypeSelector)

	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._inputModeServiceClient = self._serviceBag:GetService(InputModeServiceClient)

	self._maid = Maid.new()

	-- keep this ordered so we are always stable in selection.
	self._inputModeTypeList = {}

	self._activeModeType = self._maid:Add(ValueObject.new())

	--[=[
	Event that fires whenever the active mode changes.
	@prop Changed Signal<InputModeType, InputModeType> -- newMode, oldMode
	@within InputModeTypeSelector
]=]
	self.Changed = self._activeModeType.Changed

	for _, inputModeType in inputModesTypes or InputModeTypeSelector.DEFAULT_MODE_TYPES do
		self:AddInputModeType(inputModeType)
	end

	return self
end

--[=[
	Constructs a new InputModeTypeSelector

	@param serviceBag ServiceBag
	@param observeInputModesBrio Observable<Brio<InputModeType>>
	@return InputModeTypeSelector
]=]
function InputModeTypeSelector.fromObservableBrio(
	serviceBag: ServiceBag.ServiceBag,
	observeInputModesBrio: _Observable.Observable<_Brio.Brio<InputModeType.InputModeType>>
): InputModeTypeSelector
	local selector = InputModeTypeSelector.new(serviceBag, {})

	selector._maid:GiveTask(observeInputModesBrio:Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local inputModeType = brio:GetValue()
		local maid = brio:ToMaid()
		selector:AddInputModeType(inputModeType)

		maid:GiveTask(function()
			if selector.Destroy then
				selector:RemoveInputModeType(inputModeType)
			end
		end)
	end))

	return selector
end

--[=[
	Returns the current active mode
	@return InputModeType
]=]
function InputModeTypeSelector.GetActiveInputType(self: InputModeTypeSelector)
	return rawget(self :: any, "_activeModeType").Value
end

--[=[
	Observes the current active mode
	@return Observable<InputModeType>
]=]
function InputModeTypeSelector.ObserveActiveInputType(self: InputModeTypeSelector)
	return rawget(self :: any, "_activeModeType"):Observe()
end

--[=[
	Returns true if the input mode is the most recently activated one

	@param inputModeType InputModeType
	@return boolean
]=]
function InputModeTypeSelector.IsActive(self: InputModeTypeSelector, inputModeType: InputModeType.InputModeType)
	assert(InputModeType.isInputModeType(inputModeType), "Bad inputModeType")

	return rawget(self :: any, "_activeModeType").Value == inputModeType
end

--[=[
	Observes if the input mode is the most recently activated one

	@param inputModeType InputModeType
	@return Observable<boolean>
]=]
function InputModeTypeSelector.ObserveIsActive(
	self: InputModeTypeSelector,
	inputModeType: InputModeType.InputModeType
): _Observable.Observable<boolean>
	assert(InputModeType.isInputModeType(inputModeType), "Bad inputModeType")

	return self:ObserveActiveInputType():Pipe({
		Rx.map(function(inputType: InputModeType.InputModeType)
			return inputType == inputModeType
		end) :: any,
		Rx.distinct(),
	})
end

--[=[
	The current active input mode
	@prop Value InputModeType?
	@within InputModeTypeSelector
]=]
function InputModeTypeSelector.__index(self: InputModeTypeSelector, index)
	if index == "Value" then
		return rawget(self :: any, "_activeModeType").Value
	elseif InputModeTypeSelector[index] then
		return InputModeTypeSelector[index]
	else
		local value = rawget(self :: any, index)
		if value then
			return value
		else
			error(string.format("[InputModeTypeSelector] - Bad index '%s'", tostring(index)))
		end
	end
end

--[=[
	Binds the updateBindFunction to the mode selector

	```lua
	local inputModeTypeSelector = InputModeTypeSelector.new({
		InputModeTypes.Mouse;
		InputModeTypes.Touch;
	})

	inputModeTypeSelector:Bind(function(inputModeType)
		if inputModeType == InputModeTypes.Mouse then
			print("Show mouse input hints")
		elseif inputModeType == InputModeTypes.Touch then
			print("Show touch input hints")
		else
			-- Unknown input mode
			warn("Unknown input mode") -- should not occur
		end
	end)
	```

	@param updateBindFunction (newMode: InputModeType, modeMaid: Maid) -> ()
	@return InputModeTypeSelector
]=]
function InputModeTypeSelector.Bind(
	self: InputModeTypeSelector,
	updateBindFunction: (InputModeType.InputModeType, Maid.Maid) -> ()
): InputModeTypeSelector
	local maid = Maid.new()
	self._maid[updateBindFunction] = maid

	local function onChange(newMode, _)
		maid._modeMaid = nil

		if newMode then
			local modeMaid = Maid.new()
			maid._modeMaid = modeMaid

			if newMode then
				updateBindFunction(newMode, modeMaid)
			end
		end
	end

	maid:GiveTask(self._activeModeType.Changed:Connect(onChange))
	onChange(self._activeModeType.Value, nil)

	return self
end

--[=[
	Removes the input mode
	@param inputModeType InputModeType
]=]
function InputModeTypeSelector.RemoveInputModeType(
	self: InputModeTypeSelector,
	inputModeType: InputModeType.InputModeType
)
	assert(InputModeType.isInputModeType(inputModeType), "Bad inputModeType")

	if not self._maid[inputModeType] then
		return
	end

	local index = table.find(self._inputModeTypeList, inputModeType)
	if index then
		table.remove(self._inputModeTypeList, index)
	else
		warn("[InputModeTypeSelector] - Failed to find inputModeType")
	end

	self._maid[inputModeType] = nil

	if self._activeModeType.Value == inputModeType then
		self:_pickNewInputMode()
	end
end

--[=[
	Adds a new input mode
	@param inputModeType InputModeType
]=]
function InputModeTypeSelector.AddInputModeType(self: InputModeTypeSelector, inputModeType: InputModeType.InputModeType)
	assert(InputModeType.isInputModeType(inputModeType), "Bad inputModeType")

	if self._maid[inputModeType] then
		return
	end

	table.insert(self._inputModeTypeList, inputModeType)
	local inputMode = self._inputModeServiceClient:GetInputMode(inputModeType)
	self._maid[inputModeType] = inputMode.Enabled:Connect(function()
		self._activeModeType.Value = inputModeType
	end)

	if
		not self._activeModeType.Value
		or inputMode:GetLastEnabledTime()
			> self._inputModeServiceClient:GetInputMode(self._activeModeType.Value):GetLastEnabledTime()
	then
		self._activeModeType.Value = inputModeType
	end
end

function InputModeTypeSelector._pickNewInputMode(self: InputModeTypeSelector)
	local bestEnabledTime = -math.huge
	local bestModeType
	for _, inputModeType in self._inputModeTypeList do
		local enableTime = self._inputModeServiceClient:GetInputMode(inputModeType):GetLastEnabledTime()
		if enableTime >= bestEnabledTime then
			bestEnabledTime = enableTime
			bestModeType = inputModeType
		end
	end

	self._activeModeType.Value = bestModeType
end

--[=[
	Cleans up the input mode selector.

	:::info
	This should be called whenever the mode selector is done being used.
	:::
]=]
function InputModeTypeSelector.Destroy(self: InputModeTypeSelector)
	self._maid:DoCleaning()
	setmetatable(self :: any, nil)
end

return InputModeTypeSelector