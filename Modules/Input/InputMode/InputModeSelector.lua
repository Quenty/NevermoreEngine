local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local MakeMaid = LoadCustomLibrary("Maid").MakeMaid
local Signal = LoadCustomLibrary("Signal")
local ValueObject = LoadCustomLibrary("ValueObject")

-- Intent: Selects the most recent input mode and attempts to
-- identify the best state from it

local InputModeSelector = {}
InputModeSelector.__index = InputModeSelector
InputModeSelector.ClassName = "InputModeSelector"

function InputModeSelector.new(InputModeList, UpdateBindFunction)
	local self = setmetatable({}, InputModeSelector)
		
	self.Maid = MakeMaid()
	self.MostRecentMode = ValueObject.new()

	if InputModeList then
		self:WithInputModeList(InputModeList)
	end
	
	if UpdateBindFunction then
		self:BindUpdate(UpdateBindFunction)
	end
	
	return self
end

function InputModeSelector:BindUpdate(UpdateBindFunction)
	local BindMaid = MakeMaid()
	self.Maid[UpdateBindFunction] = BindMaid
	
	local function HandleChange(NewMode, OldMode)
		BindMaid.CurrentMaid = nil
		
		if NewMode then
			local Maid = MakeMaid()
			BindMaid.CurrentMaid = Maid
			
			UpdateBindFunction(NewMode, Maid)
		end
	end

	BindMaid.Changed = self.MostRecentMode.Changed:connect(HandleChange)
	HandleChange(self.MostRecentMode.Value)
	
	return self
end

function InputModeSelector:WithInputModeList(InputModeList)
	local BestInputModeState
	local BestTimeEnabled = -math.huge
	
	for _, InputModeState in pairs(InputModeList) do
		if InputModeState:GetLastEnabledTime() > BestTimeEnabled then
			BestTimeEnabled = InputModeState:GetLastEnabledTime()
			BestInputModeState = InputModeState
		end
		
		self.Maid[InputModeState] = InputModeState.Enabled:connect(function()
			self.MostRecentMode.Value = InputModeState
		end)
	end
	
	self.MostRecentMode.Value = BestInputModeState

	return self
end

function InputModeSelector:Destroy()
	self.Maid:DoCleaning()
end


return InputModeSelector