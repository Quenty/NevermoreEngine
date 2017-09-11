local RunService = game:GetService("RunService")

local HeldRateInput = {}
HeldRateInput.__index = HeldRateInput
HeldRateInput.ClassName = "HeldRateInput"
HeldRateInput.Rate = 1
HeldRateInput.Acceleration = 1.5

--- Like a Heldkey, but with an increasing rate
-- @author Quenty

function HeldRateInput.new(RepeatFunction)
	-- Holding down a key to repeat an action handled by this
	-- @param [RepeatFunction] The function to repeatedly call as the key is held down
		-- RepeatFunction(Delta, IsLast)
			-- @param Delta The rate to change by.
				-- Starts at 1
				-- Goes to infinity.
			-- @param IsLast True

	local self = {}
	setmetatable(self, HeldRateInput)
	
	self.RepeatFunction = RepeatFunction or error("No repeating function")
	self.PressId = 0
	
	return self
end

function HeldRateInput:HandleNewState(UserInputState)
	-- When there's an input change, this handles the behavior.
	
	if UserInputState.Name == "Begin" then
		self.PressId = self.PressId + 1
		local LocalPressId = self.PressId
		
		local StartTime = tick()
		local LastUpdate = StartTime

		self.RepeatFunction(1, Enum.UserInputState.Begin) -- Initially
		local RenderStepBindKey = tostring(self) .. "_HeldKey" .. LocalPressId
		RunService:BindToRenderStep(RenderStepBindKey, 101, function()
			local Time = tick()
			local dt = Time - LastUpdate
			
			
			local Delta = (self.Acceleration^(LastUpdate-StartTime) * self.Acceleration^dt-1)/math.log(self.Acceleration)
			Delta = Delta*self.Rate
			
			if LocalPressId == self.PressId then
				self.RepeatFunction(Delta, Enum.UserInputState.Change)
			else
				self.RepeatFunction(Delta, Enum.UserInputState.End)
				RunService:UnbindFromRenderStep(RenderStepBindKey)
			end
			
			LastUpdate = Time
		end)
	elseif UserInputState.Name == "End" then
		self:Stop()
	end
end

function HeldRateInput:Stop()
	self.PressId = self.PressId + 1
end


return HeldRateInput
