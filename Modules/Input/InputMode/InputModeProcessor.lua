-- Intent: Process inputs by evaluating states 

local InputModeProcessor = {}
InputModeProcessor.__index = InputModeProcessor
InputModeProcessor.ClassName = InputModeProcessor

function InputModeProcessor.new()
	local self = setmetatable({}, InputModeProcessor)
	
	self.InputModeStates = {}
	
	return self
end

function InputModeProcessor:AddState(State)
	self.InputModeStates[#self.InputModeStates+1] = State or error()
	
	return self
end

function InputModeProcessor:GetStates()
	return self.InputModeStates
end

function InputModeProcessor:Evaluate(InputObject)
	for _, InputState in pairs(self.InputModeStates) do
		InputState:Evaluate(InputObject)
	end
end

return InputModeProcessor