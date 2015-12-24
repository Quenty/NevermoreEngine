local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local Signal            = LoadCustomLibrary("Signal")
local BindableAction    = LoadCustomLibrary("BindableAction")

-- Binds and unbinds select commands on request.
-- Allows for better handling of bind states (that is, cleanup and initalizing commands).
-- @author Quenty

local InputBind = {}
InputBind.__index = InputBind
InputBind.ClassName = "InputBind"

function InputBind.new()
	local self = {}
	setmetatable(self, InputBind)
	
	-- Contains already / actively bound items
	self.BoundActions = {}

	-- Contains the list of actions to bind
	self.AllActions = {} -- [Name] = Table `ActionData` {}

	self.IsCurrentlyBound = false

	self.ActionBound   = Signal.new()
	self.ActionUnbound = Signal.new()
	
	return self
end

-- PUBLIC FUNCTIONS
function InputBind:GetActions()
	return self.AllActions
end

function InputBind:AddAction(Action)
	--- Adds a new BindableAction into the system.
	-- @param Action BindableAction, the action to add into the system

	self.AllActions[Action:GetName()] = Action

	if self:IsBound() then
		self:BindAction(Action)
	end

	return Action
end

function InputBind:GetAction(ActionName)
	return self.AllActions[ActionName]
end

function InputBind:Add(ActionName, Function, CreateTouchButton, ...)
	return self:AddAction(BindableAction.FromUsualInput(ActionName, Function, CreateTouchButton, ...))
end

function InputBind:AddFromData(ActionData)
	--- Adds a new action from data
	-- @param ActionData Table, contains information to call BindableAction.FromData to construct from.
	--[[
		ActionData = {
			ActionName = "Start_Flying";
			FunctionToBind = function(ActionName, UserInputState, InputObject)
				-- Use UserInputState to determine whether the input is beginning or endnig
			end;
			CreateTouchButton = false;
			[ButtonTitle] = "Fly";
			[ButtonImage] = "rbxassetid://137511721";
			[InternalDescription] = "Start flying";
			InputTypes = {Enum.UserInputType.Accelerometer, Enum.KeyCode.E, Enum.KeyCode.F};
		}
	--]]
	-- @return The new action

	local NewAction = BindableAction.FromData(ActionData)
	self:AddAction(NewAction)

	return NewAction
end

function InputBind:IsBound()
	-- Returns whether or not the input is already bound. 

	return self.IsCurrentlyBound
end

function InputBind:BindInput()
	-- Binds all the action to input.

	assert(not self.IsCurrentlyBound, "Already bound")
	self.IsCurrentlyBound = true

	for _, Action in pairs(self.AllActions) do
		if not self.BoundActions[Action:GetName()] then
			self:BindAction(Action)
		end
	end
end

function InputBind:UnbindInput()
	-- Unbinds all actions associated with the interface. Used on
	-- GC most of the time.

	assert(self.IsCurrentlyBound, "Already unbound")
	self.IsCurrentlyBound = false

	for ActionName, Action in pairs(self.BoundActions) do
		self:UnbindAction(ActionName)
	end
end



-- PRIVATE FUNCTIONS

function InputBind:BindAction(Action)
	--- Binds an action to the ContextActionService and to the input manager
	-- @param Action The action to bind.

	assert(not self.BoundActions[Action:GetName()], "Action is already bound")

	Action:Bind()

	self.BoundActions[Action:GetName()] = Action
	self.ActionBound:fire(Action)
end

function InputBind:UnbindAction(ActionName)
	local Action = self.BoundActions[ActionName]
	assert(Action, "Action '" .. ActionName .. "' is not bound")

	Action:Unbind()

	self.BoundActions[ActionName] = nil
	self.ActionUnbound:fire(Action)
end

return InputBind