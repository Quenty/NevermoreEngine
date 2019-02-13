--- Process inputs by evaluating states
-- @classmod InputModeProcessor

local InputModeProcessor = {}
InputModeProcessor.__index = InputModeProcessor
InputModeProcessor.ClassName = InputModeProcessor

function InputModeProcessor.new()
	local self = setmetatable({}, InputModeProcessor)

	self._inputModes = {}

	return self
end

function InputModeProcessor:AddState(state)
	self._inputModes[#self._inputModes+1] = state or error("No state")

	return self
end

function InputModeProcessor:GetStates()
	return self._inputModes
end

function InputModeProcessor:Evaluate(inputObject)
	for _, inputMode in pairs(self._inputModes) do
		inputMode:Evaluate(inputObject)
	end
end

return InputModeProcessor