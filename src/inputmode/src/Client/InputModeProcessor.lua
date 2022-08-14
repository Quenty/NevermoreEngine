--[=[
	Process inputs by evaluating inputModes. Helper object..

	@class InputModeProcessor
]=]

local InputModeProcessor = {}
InputModeProcessor.__index = InputModeProcessor
InputModeProcessor.ClassName = InputModeProcessor

--[=[
	Construtcs a new inputModeProcessor
	@param inputModes { InputMode }?
	@return InputModeProcessor
]=]
function InputModeProcessor.new(inputModes)
	local self = setmetatable({}, InputModeProcessor)

	self._inputModes = {}

	if inputModes then
		for _, inputMode in pairs(inputModes) do
			self:AddInputMode(inputMode)
		end
	end

	return self
end

function InputModeProcessor:AddInputMode(inputMode)
	table.insert(self._inputModes, inputMode)
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