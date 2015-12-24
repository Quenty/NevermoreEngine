local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local NevermoreEngine      = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary    = NevermoreEngine.LoadLibrary

local Signal               = LoadCustomLibrary("Signal")
local MakeMaid             = LoadCustomLibrary("Maid").MakeMaid

--- Translates the ContextActionService binding into an OOP object with event-based properties. 
-- @author Quenty

local BindableAction = {}
BindableAction.ClassName = "BindableAction"
BindableAction.__index = BindableAction

function BindableAction.new(ActionName, InputTypes)
	local self = {}
	setmetatable(self, BindableAction)

	-- DATA
	self.ActionName        = ActionName or error("[BindableAction] - Need ActionName")
	self.InputTypes        = InputTypes or error("[BindableAction] - Need InputTypes")
	self.ButtonTitle       = ActionName
	self.CreateTouchButton = false

	-- PRIVATE
	self.IsBoundState      = false
	
	-- EVENTS
	self.BoundFunctionMaid = MakeMaid()
	self.ActionFired       = Signal.new() -- Fires upon action fired. Suggested that you use :BindFunction(Name, Function) instead. 
	self.Bound             = Signal.new() -- Fires upon bind
	self.Unbound           = Signal.new() -- Firse upon unbind

	return self
end

function BindableAction.FromUsualInput(ActionName, Function, CreateTouchButton, ...)
	local New = BindableAction.new(ActionName or error("No ActionName"), {...})

	if CreateTouchButton ~= nil then
		New:SetCreateTouchButton(CreateTouchButton)
	end

	if type(Function) == "function" then
		New:BindFunction("Primary", Function)
	else
		error("Function must be a function");
	end

	return New
end

function BindableAction.FromData(Data)
	--- Construct from table
	--[[
		Data = {
			ActionName = "Start_Flying";
			FunctionToBind = function(ActionName, UserInputState, InputObject)
				-- Use UserInputState to determine whether the input is beginning or endnig
			end;
			[FunctionToBind] = {
				... -- Bind multiple functions
			}
			CreateTouchButton = false;
			[ButtonTitle] = "Fly";
			[ButtonImage] = "rbxassetid://137511721";
			[InternalDescription] = "Start flying";
			InputTypes = {Enum.UserInputType.Accelerometer, Enum.KeyCode.E, Enum.KeyCode.F};
		}
	--]]

	local New = BindableAction.new(Data.ActionName or error("No ActionName"), Data.InputTypes or error("NO InputTypes"))

	if Data.CreateTouchButton ~= nil then
		New:SetCreateTouchButton(Data.CreateTouchButton)
	end

	-- BUTTON
	if Data.ButtonTitle then
		New:SetButtonTitle(Data.ButtonTitle)
	end
	if Data.ButtonImage then
		New:SetButtonImage(Data.ButtonImage)
	end

	-- DESCRIPTION
	if Data.InternalDescription then
		New:SetInternalDescription(Data.InternalDescription)
	end

	-- FUNCTION
	if type(Data.FunctionToBind) == "function" then
		New:BindFunction("Primary", Data.FunctionToBind)
	elseif type(Data.FunctionToBind) == "table" then
		for Name, Function in pairs(Data.FunctionToBind) do
			New:BindFunction(Name, Function)
		end
	end

	return New
end

function BindableAction:SetCreateTouchButton(DoCreateTouchButton)
	-- @param DoCreateTouchButton Boolean, should the action create a touch button
	-- Will not change until rebound. 

	assert(type(DoCreateTouchButton) == "boolean", "DoCreateTouchButton must be a boolean")

	self.CreateTouchButton = DoCreateTouchButton
end

function BindableAction:GetInputTypes()
	return self.InputTypes
end

function BindableAction:IsBound()
	-- @return Boolean, true if the action is bound

	return self.IsBoundState
end

function BindableAction:GetName()
	-- @return The action's name

	return self.ActionName
end

function BindableAction:SetButtonTitle(ButtonTitle)
	assert(type(ButtonTitle) == "string", "ButtonTitle must be a string")

	self.ButtonTitle = ButtonTitle

	if self:IsBound() then
		ContextActionService:SetTitle(self.ActionName, self.ButtonTitle)
	end
end

function BindableAction:SetButtonImage(ButtonImage)
	assert(type(ButtonImage) == "string", "ButtonImage must be a string")

	self.ButtonImage = ButtonImage

	if self:IsBound() then
		ContextActionService:SetImage(self.ActionName, self.ButtonImage)
	end
end

function BindableAction:SetInternalDescription(Description)
	--- Sets the internal description

	self.InternalDescription = Description

	if self:IsBound() then
		ContextActionService:SetDescription(self.ActionName, self.InternalDescription)
	end
end

function BindableAction:BindFunction(Name, Function)
	---Binds the to the BindableAction's FireBound event. :)

	-- Did some tests. When the BindableAction is GCed, this will also GC the signal and method. So Maid:DoCleaning() need not be called
	-- to finalize GC even with anonymous functions.

	assert(type(Name) == "string", "Name must be a string")
	assert(type(Function) == "function", "Function must be a function")

	self.BoundFunctionMaid[Name] = self.ActionFired:connect(Function)
end

function BindableAction:UnbindFunction(Name)
	--- Binds a function from the action

	assert(self.BoundFunctionMaid[Name], "Bound function does not exist")

	self.BoundFunctionMaid[Name] = nil
end

function BindableAction:FireBound(ActionName, UserInputState, InputObject)
	-- Used by the InputBind

	self.ActionFired:fire(ActionName, UserInputState, InputObject)
end

function BindableAction:Bind()
	assert(not self:IsBound(), "Already bound")
	self.IsBoundState = true

	ContextActionService:BindActionToInputTypes(	
		self.ActionName or error("No action name"),
		function(...)
			self.ActionFired:fire(...)
		end,
		self.CreateTouchButton,
		unpack(self.InputTypes)
	)

	if self.CreateTouchButton then
		if self.ButtonTitle then
			ContextActionService:SetTitle(self.ActionName, self.ButtonTitle)
		end
		
		if self.ButtonImage then
			ContextActionService:SetImage(self.ActionName, self.ButtonImage)
		end
	end
		
	if self.InternalDescription then
		ContextActionService:SetDescription(self.ActionName, self.InternalDescription)
	end

	self.Bound:fire()
end

function BindableAction:Unbind()
	--- Unbinds the action from ContextActionService. Should be done to ensure GC.

	assert(self:IsBound(), "Already unbound")
	self.IsBoundState = false

	ContextActionService:UnbindAction(self.ActionName)
	self.Unbound:fire()
end

return BindableAction