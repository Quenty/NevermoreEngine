local HeldInput = {}
HeldInput.__index = HeldInput
HeldInput.ClassName = "HeldInput"

-- @author Quenty

function HeldInput.new(RepeatFunction)
	-- Holding down a key to repeat an action handled by this
	-- @param [RepeatFunction] The function to repeatedly call as the key is held down
	
	local self = {}
	setmetatable(self, HeldInput)
	
	self.RepeatFunction = RepeatFunction or error("No repeating function")
	self.PressId = 0
	
	return self
end

function HeldInput:HandleNewState(UserInputState)
	-- When there's an input change, this handles the behavior.
	
	if UserInputState.Name == "Begin" then
		self.PressId = self.PressId + 1
		local LocalPressId = self.PressId
		
		self.RepeatFunction()
		delay(0.2, function()
			while LocalPressId == self.PressId do
				self.RepeatFunction()
				wait(0.2)
			end
		end)
		
	elseif UserInputState.Name == "End" then
		self:Stop()
	end
end

function HeldInput:Stop()
	self.PressId = self.PressId + 1
end

return HeldInput
