local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local Maid.new = LoadCustomLibrary("Maid").Maid.new
local ValueObject = LoadCustomLibrary("ValueObject")

-- Intent: Selects the most recent input mode and attempts to
-- identify the best state from it

local InputModeSelector = {}
InputModeSelector.__index = InputModeSelector
InputModeSelector.ClassName = "InputModeSelector"

function InputModeSelector.new(inputModeList, updateBindFunction)
	local self = setmetatable({}, InputModeSelector)
		
	self._maid = Maid.new()
	self.MostRecentMode = ValueObject.new()

	if inputModeList then
		self:WithInputModeList(inputModeList)
	end
	
	if updateBindFunction then
		self:BindUpdate(updateBindFunction)
	end
	
	return self
end

function InputModeSelector:BindUpdate(updateBindFunction)
	local bindMaid = Maid.new()
	self._maid[updateBindFunction] = bindMaid
	
	local function HandleChange(NewMode, OldMode)
		bindMaid.CurrentMaid = nil
		
		if NewMode then
			local maid = Maid.new()
			bindMaid.CurrentMaid = maid
			
			updateBindFunction(NewMode, maid)
		end
	end

	bindMaid.Changed = self.MostRecentMode.Changed:Connect(HandleChange)
	HandleChange(self.MostRecentMode.Value)
	
	return self
end

function InputModeSelector:WithInputModeList(inputModeList)
	local mostRecentInputMode = nil
	local mostRecentTime = -math.huge
	
	for _, inputModeState in pairs(inputModeList) do
		if inputModeState:GetLastEnabledTime() > mostRecentTime then
			mostRecentTime = inputModeState:GetLastEnabledTime()
			mostRecentInputMode = inputModeState
		end
		
		self._maid[inputModeState] = inputModeState.Enabled:Connect(function()
			self.MostRecentMode.Value = inputModeState
		end)
	end
	
	self.MostRecentMode.Value = mostRecentInputMode

	return self
end

function InputModeSelector:Destroy()
	self._maid:DoCleaning()
end


return InputModeSelector