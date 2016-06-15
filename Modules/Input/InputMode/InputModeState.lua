local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local Signal            = LoadCustomLibrary("Signal")

-- Intent: Trace input mode state and trigger changes correctly

local InputModeState = {}
InputModeState.__index = InputModeState
InputModeState.ClassName = "InputModeState"

function InputModeState.new(Valid)
	local self = setmetatable({}, InputModeState)
	
	self.LastEnabled = 0
	self.Enabled = Signal.new()
	self.Valid = Valid or {}
	
	return self
end

function InputModeState:AddKeys(Keys, EnumSet)
	-- @param Keys A string for ease of use, or a table of keys
	-- @param [EnumSet] The enum set to pull from. Defaults to KeyCode.
	
	EnumSet = EnumSet or Enum.KeyCode
	
	if type(Keys) == "string" then
		local NewKeys = {}
		for Key in Keys:gmatch("%w+") do
			NewKeys[#NewKeys+1] = Key
		end
		Keys = NewKeys
	end
	
	for _, Key in pairs(Keys) do
		if type(Key) == "string" then
			Key = EnumSet[Key]
		end
		
		self.Valid[Key] = true;
	end
	
	return self
end

function InputModeState:GetKeys()
	local Keys = {}
	for Key, _ in pairs(self.Valid) do
		Keys[#Keys+1] = Key
	end
	return Keys
end

function InputModeState:IsValid(InputType)
	-- @param InputType Maybe be a UserInputType or KeyCode
	assert(InputType, "Must send in InputType")
	
	return self.Valid[InputType]
end

function InputModeState:Enable()
	self.LastEnabled = tick()
	self.Enabled:fire()
end

function InputModeState:Evaluate(InputObject)
	if self:IsValid(InputObject.UserInputType) or self:IsValid(InputObject.KeyCode) then
		self:Enable()
	end
end

return InputModeState