--[=[
	Process inputs by evaluating inputModes. Typically not used directly, but rather, just
	use modes from INPUT_MODES.

	@class InputModeProcessor
]=]

local InputModeProcessor = {}
InputModeProcessor.__index = InputModeProcessor
InputModeProcessor.ClassName = InputModeProcessor

--[=[
	Construtcs a new inputModeProcessor
	@param inputModes { InputMode }
	@return InputModeProcessor
]=]
function InputModeProcessor.new(inputModes)
	local self = setmetatable({}, InputModeProcessor)

	self._inputModes = {}

	for _, state in pairs(inputModes) do
		self._inputModes[#self._inputModes+1] = state
	end

	return self
end

--[=[
	Gets all input mode inputModes being used
	@return { InputMode }
]=]
function InputModeProcessor:GetStates()
	return self._inputModes
end

--[=[
	Applies the inputObject as an evaluation for the inputm odes
	@param inputObject InputObject
]=]
function InputModeProcessor:Evaluate(inputObject)
	for _, inputMode in pairs(self._inputModes) do
		inputMode:Evaluate(inputObject)
	end
end

return InputModeProcessor