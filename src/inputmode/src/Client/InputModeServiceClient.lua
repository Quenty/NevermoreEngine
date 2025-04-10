--!strict
--[=[
	Centralized
	@class InputModeServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local InputModeType = require("InputModeType")
local Maid = require("Maid")
local InputModeProcessor = require("InputModeProcessor")
local InputModeTypes = require("InputModeTypes")
local InputMode = require("InputMode")
local _ServiceBag = require("ServiceBag")

local THUMBSTICK_DEADZONE = 0.14

local InputModeServiceClient = {}
InputModeServiceClient.ServiceName = "InputModeServiceClient"

export type InputModeServiceClient = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_inputModes: { [InputModeType.InputModeType]: InputMode.InputMode },
		_inputModeProcessor: InputModeProcessor.InputModeProcessor,
		_lastMousePosition: Vector3?,
		_serviceBag: _ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = InputModeServiceClient })
))

function InputModeServiceClient.Init(self: InputModeServiceClient, serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid = Maid.new()
	self._inputModes = {}

	self._inputModeProcessor = InputModeProcessor.new()

	-- order semi-matters. general should come first, to non-specific. that way, specific stuff has
	-- priority over non-specific input modes.
	self:GetInputMode(InputModeTypes.KeyboardAndMouse)
	self:GetInputMode(InputModeTypes.Gamepads)
	self:GetInputMode(InputModeTypes.Keyboard)
	self:GetInputMode(InputModeTypes.Touch)
	self:GetInputMode(InputModeTypes.Mouse)
	self:GetInputMode(InputModeTypes.ArrowKeys)
	self:GetInputMode(InputModeTypes.Keypad)
	self:GetInputMode(InputModeTypes.WASD)
	self:GetInputMode(InputModeTypes.DPad)
	-- Don't add InputModeTypes.Thumbsticks, we handle it seperately

	self:_triggerEnabled()
	self:_bindProcessor()
end

function InputModeServiceClient.GetInputMode(
	self: InputModeServiceClient,
	inputModeType: InputModeType.InputModeType
): InputMode.InputMode
	assert(InputModeType.isInputModeType(inputModeType), "Bad inputModeType")

	if not RunService:IsRunning() then
		if not self._inputModes then
			-- fake it till we make it!
			local inputMode = InputMode.new(inputModeType)
			local lastInputType = UserInputService:GetLastInputType()

			-- Hack processing
			if inputModeType:IsValid(lastInputType) then
				inputMode:Enable()
			end

			if inputModeType == InputModeTypes.Keyboard or inputModeType == InputModeTypes.KeyboardAndMouse then
				inputMode:Enable()
			end

			return inputMode
		end
	end

	if self._inputModes[inputModeType] then
		return self._inputModes[inputModeType]
	end

	local inputMode = InputMode.new(inputModeType)
	self._inputModeProcessor:AddInputMode(inputMode)
	self._maid:GiveTask(inputMode)

	self._inputModes[inputModeType] = inputMode
	return inputMode
end

function InputModeServiceClient._triggerEnabled(self: InputModeServiceClient)
	if UserInputService.MouseEnabled then
		self:GetInputMode(InputModeTypes.Mouse):Enable()
	end
	if UserInputService.TouchEnabled then
		self:GetInputMode(InputModeTypes.Touch):Enable()
	end
	if UserInputService.KeyboardEnabled then
		self:GetInputMode(InputModeTypes.Keyboard):Enable()
	end
	if UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
		self:GetInputMode(InputModeTypes.KeyboardAndMouse):Enable()
	end
	if
		UserInputService.GamepadEnabled
		or #UserInputService:GetConnectedGamepads() > 0
		or GuiService:IsTenFootInterface()
	then
		self:GetInputMode(InputModeTypes.Gamepads):Enable()
	end
end

function InputModeServiceClient._bindProcessor(self: InputModeServiceClient)
	self._maid:GiveTask(UserInputService.InputBegan:Connect(function(inputObject: InputObject)
		self._inputModeProcessor:Evaluate(inputObject)
	end))
	self._maid:GiveTask(UserInputService.InputEnded:Connect(function(inputObject: InputObject)
		self._inputModeProcessor:Evaluate(inputObject)
	end))
	self._maid:GiveTask(UserInputService.InputChanged:Connect(function(inputObject: InputObject)
		if inputObject.KeyCode == Enum.KeyCode.Thumbstick1 or inputObject.KeyCode == Enum.KeyCode.Thumbstick2 then
			if inputObject.Position.Magnitude > THUMBSTICK_DEADZONE then
				self._inputModeProcessor:Evaluate(inputObject)
				self:GetInputMode(InputModeTypes.Thumbsticks):Enable()
			end
		elseif inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			-- Prevent mouse movement from flickering
			if self:_shouldProcessMouseMovement(inputObject) then
				self._inputModeProcessor:Evaluate(inputObject)
			end
		else
			self._inputModeProcessor:Evaluate(inputObject)
		end
	end))

	self._maid:GiveTask(UserInputService.GamepadConnected:Connect(function(_)
		self:GetInputMode(InputModeTypes.Gamepads):Enable()
	end))

	self._maid:GiveTask(UserInputService.GamepadDisconnected:Connect(function(_)
		self:_triggerEnabled()
	end))
end

function InputModeServiceClient._shouldProcessMouseMovement(
	self: InputModeServiceClient,
	inputObject: InputObject
): boolean
	-- Prevent mouse movement from flickering
	local position = inputObject.Position
	local lastMousePosition: Vector3? = self._lastMousePosition
	self._lastMousePosition = position

	if inputObject.Delta.Magnitude > 0 then
		return true
	end

	if not lastMousePosition then
		return true
	end

	if (lastMousePosition - position).Magnitude > 0 then
		return true
	end

	return false
end

function InputModeServiceClient.Destroy(self: InputModeServiceClient)
	self._maid:DoCleaning()
end

return InputModeServiceClient