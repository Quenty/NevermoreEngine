-- Intent: Process inputs by evaluating states 

local InputModeProcessor = {}
InputModeProcessor.__index = InputModeProcessor
InputModeProcessor.ClassName = InputModeProcessor

function InputModeProcessor.new()
	local self = setmetatable({}, InputModeProcessor)
	
	self.InputModes = {}
	
	return self
end

function InputModeProcessor:AddState(State)
	self.InputModes[#self.InputModes+1] = State or error()
	
	return self
end

function InputModeProcessor:GetStates()
	return self.InputModes
end

function InputModeProcessor:Evaluate(InputObject)
	for _, InputMode in pairs(self.InputModes) do
		InputMode:Evaluate(InputObject)
	end
end

return InputModeProcessor