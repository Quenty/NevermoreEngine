local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local Signal            = LoadCustomLibrary("Signal")
local MakeMaid          = LoadCustomLibrary("Maid").MakeMaid

-- Intent: Handle the swap between input modes

local InputModeSwapper = {}
InputModeSwapper.__index = InputModeSwapper
InputModeSwapper.ClassName = "InputModeSwapper"

function InputModeSwapper.new(EnableMethodName, DisableMethodName)
	local self = setmetatable({}, InputModeSwapper)
	
	self.Maid = MakeMaid()
	
	self.Buttons = {} -- [Button] = InputModeState
	self.DisableStates = {} -- These states always disable
	self.EnableMethodName = EnableMethodName or "Show"
	self.DisableMethodName = DisableMethodName or "Hide"
	
	self.StateHandlerAdded = Signal.new() -- :fire(InputModeState, Handler)
	
	self.Enabled = true
	
	return self
end

function InputModeSwapper:Disable()
	--- Stops the swapper from swapping. Disables events.
	
	if self.Enabled then
		self.Enabled = false
		
		-- Disable all the things.
		self:DeactivateCurrent()
		
		self.Maid:DoCleaning()
		self.Maid = nil
	end
	
	return self
end

function InputModeSwapper:Enable()
	--- Enables the swapper for swapping. Connects events.
	
	if not self.Enabled then
		self.Enabled = true
		
		-- Rebind all the inputs and whatnot.
		
		self.Maid = MakeMaid()
		local LastActivated 
		for Button, InputModeState in pairs(self.Buttons) do
			if not LastActivated then
				LastActivated = Button
			elseif self.Buttons[LastActivated].LastEnabled < self.Buttons[Button].LastEnabled then
				LastActivated = Button
			end
			
			self.Maid[Button] = InputModeState.Enabled:connect(function()
				self:Activate(Button)
			end)
		end
		
		for _, InputModeState in pairs(self.DisableStates) do
			if LastActivated and self.Buttons[LastActivated].LastEnabled < InputModeState.LastEnabled then
				LastActivated = nil
			end
			
			self.Maid[InputModeState] = InputModeState.Enabled:connect(function()
				self:DeactivateCurrent()
			end)
		end
		
		if LastActivated then
			self:Activate(LastActivated)
		end
	end
	
	return self
end

function InputModeSwapper:DeactivateCurrent()
	if self.ActiveButton then
		local Button = self.ActiveButton or error("No active button")
		local InputModeState = self.Buttons[Button]
		
		if self.Enabled then
			-- Reconnect the InputModeSwapper
			self.Maid[Button] = InputModeState.Enabled:connect(function()
				self:Activate(Button)
			end)
		end
		
		Button[self.DisableMethodName](Button)
		self.ActiveSignal = nil
	end
end

function InputModeSwapper:Activate(Button)
	if self.Enabled then
		self:DeactivateCurrent()
		
		-- Disconnect to state chages 
		self.Maid[Button] = nil
		self.ActiveButton = Button
		
		-- Show the button.
		Button[self.EnableMethodName](Button)
	else
		error("Can't activate now! Swapper disabled!")
	end
end

function InputModeSwapper:GetHandlers()
	return self.Buttons -- [Handler] = InputModeState
end

function InputModeSwapper:WithDisableState(InputModeState)
	if self.Enabled then
		self.Maid[InputModeState] = InputModeState.Enabled:connect(function()
			self:DeactivateCurrent()
		end)
	end
	
	self.DisableStates[#self.DisableStates+1] = InputModeState
	
	return self
end

function InputModeSwapper:WithHandler(InputModeState, Button)
	-- @param Button Anything with a :Show() method.
	
	assert(InputModeState, "Must pass in InputModeState")
	assert(Button, "Must pass in Button")
	assert(type(Button[self.EnableMethodName]) == "function", "Button must have '" .. self.EnableMethodName .. "' method in it");
	assert(type(Button[self.DisableMethodName]) == "function", "Button must have '" .. self.DisableMethodName .. "' method in it");
	assert(InputModeState.LastEnabled, "Must have LastEnabled value in InputModeState")
	
	if self.Enabled then
		self.Maid[Button] = InputModeState.Enabled:connect(function()
			self:Activate(Button)
		end)
	end
		
	self.Buttons[Button] = InputModeState
	self.StateHandlerAdded:fire(InputModeState, Button)

	if self.Enabled then
		if not self.ActiveButton then
			self:Activate(Button)
		elseif self.Buttons[self.ActiveButton].LastEnabled < InputModeState.LastEnabled then
			self:Activate(Button)
		else
			Button[self.DisableMethodName](Button)
		end
	else
		Button[self.DisableMethodName](Button)
	end
	
	
	return self
end

function InputModeSwapper:Destroy()
	--self:DeactivateCurrent()
	
	if self.Maid then
		self.Maid:DoCleaning()
		self.Maid = nil
	end
	
	self.Buttons = nil
	self.DisableStates = nil
	
	setmetatable(self, nil)
end

return InputModeSwapper