local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local MakeMaid = LoadCustomLibrary("Maid").MakeMaid
local Signal = LoadCustomLibrary("Signal")
local ValueObject = LoadCustomLibrary("ValueObject")

-- Intent: Selects the most recent input mode and attempts to
-- identify the best state from it

local InputModeSelector = {}
InputModeSelector.__index = InputModeSelector
InputModeSelector.ClassName = "InputModeSelector"

function InputModeSelector.new(InputModeStates, UpdateBindFunction)
	local self = setmetatable({}, InputModeSelector)
	
	self.BestState = ValueObject.new()
	
	self.Maid = MakeMaid()

	if InputModeStates then
		self:WithInputModeStates(InputModeStates)
	end
	
	if UpdateBindFunction then
		self:BindUpdate(UpdateBindFunction)
	end
	
	return self
end

function InputModeSelector:BindUpdate(UpdateBindFunction)
	local BindMaid = MakeMaid()
	self.Maid[UpdateBindFunction] = BindMaid
	
	local function HandleChange(NewState, OldState)
		BindMaid.CurrentMaid = nil
		
		if NewState then
			local Maid = MakeMaid()
			BindMaid.CurrentMaid = Maid
			
			UpdateBindFunction(NewState, Maid)
		end
	end

	BindMaid.Changed = self.BestState.Changed:connect(HandleChange)
	HandleChange(self.BestState.Value)
	
	return self
end

function InputModeSelector:WithInputModeStates(InputModeStates)
	local BestInputModeState
	local BestTimeEnabled = -math.huge
	
	for _, InputModeState in pairs(InputModeStates) do
		if InputModeState:GetLastEnabledTime() > BestTimeEnabled then
			BestTimeEnabled = InputModeState:GetLastEnabledTime()
			BestInputModeState = InputModeState
		end
		
		self.Maid[InputModeState] = InputModeState.Enabled:connect(function()
			self.BestState.Value = InputModeState
		end)
	end
	
	self.BestState.Value = BestInputModeState

	return self
end

function InputModeSelector:Destroy()
	self.Maid:DoCleaning()
end


return InputModeSelector