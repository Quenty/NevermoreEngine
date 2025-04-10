--[=[
	Process inputs by evaluating inputModes. Helper object..

	@class InputModeProcessor
]=]

local require = require(script.Parent.loader).load(script)

local _InputMode = require("InputMode")

local InputModeProcessor = {}
InputModeProcessor.__index = InputModeProcessor
InputModeProcessor.ClassName = InputModeProcessor

export type InputModeProcessor = typeof(setmetatable(
	{} :: {
		_inputModes: { _InputMode.InputMode },
	},
	{} :: typeof({ __index = InputModeProcessor })
))

--[=[
	Construtcs a new inputModeProcessor
	@param inputModes { InputMode }?
	@return InputModeProcessor
]=]
function InputModeProcessor.new(inputModes: { _InputMode.InputMode }?): InputModeProcessor
	local self = setmetatable({}, InputModeProcessor)

	self._inputModes = {}

	if inputModes then
		for _, inputMode in inputModes do
			self:AddInputMode(inputMode)
		end
	end

	return self
end

--[=[
	Adds an input mode to the inputModeProcessor
	@param inputMode InputMode
]=]
function InputModeProcessor.AddInputMode(self: InputModeProcessor, inputMode: _InputMode.InputMode)
	table.insert(self._inputModes, inputMode)
end

--[=[
	Gets all input mode inputModes being used
	@return { InputMode }
]=]
function InputModeProcessor.GetStates(self: InputModeProcessor): { _InputMode.InputMode }
	return self._inputModes
end

--[=[
	Applies the inputObject as an evaluation for the inputm odes
	@param inputObject InputObject
]=]
function InputModeProcessor.Evaluate(self: InputModeProcessor, inputObject: InputObject)
	for _, inputMode in self._inputModes do
		inputMode:Evaluate(inputObject)
	end
end

return InputModeProcessor