local HeldInput = {}
HeldInput.__index = HeldInput
HeldInput.ClassName = "HeldInput"
HeldInput.DelayTime = 0.2
HeldInput.InitialDelayTime = 0.2

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
		delay(self.InitialDelayTime, function()
			while LocalPressId == self.PressId do
				self.RepeatFunction()
				wait(self.DelayTime)
			end
		end)
	elseif UserInputState.Name == "End" then
		self:Stop()
	end
end

function HeldInput:Stop()
	self.PressId = self.PressId + 1
end

function HeldInput:WithDelayTime(Time)
	--- The time to delay between each instance of a siulated press

	self.DelayTime = Time

	return self
end

function HeldInput:WithInitialDelayTime(Time)
	self.InitialDelayTime = Time

	return self
end

return HeldInput
