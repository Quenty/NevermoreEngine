local ContextActionService  = game:GetService("ContextActionService")
local ReplicatedStorage     = game:GetService("ReplicatedStorage")

local NevermoreEngine       = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary     = NevermoreEngine.LoadLibrary

local Signal                = LoadCustomLibrary("Signal")

-- Binds and unbinds select commands on request.
-- @author Quenty

local InputBind = {}
InputBind.__index = InputBind
InputBind.ClassName = "InputBind"

function InputBind.new()
	local self = {}
	setmetatable(self, InputBind)
	
	-- Contains already / actively bound items
	self.BoundActionsMap = {}

	-- Contains the list of actions to bind
	self.ActionDataList = {} -- [Name] = Table `ActionData` {}

	self.IsCurrentlyBound = false

	self.ActionBound   = Signal.new()
	self.ActionUnbound = Signal.new()
	
	return self
end

-- PUBLIC FUNCTIONS

function InputBind:GetActionMap()
	return self.BoundActionsMap
end

function InputBind:AddAction(ActionData)
	--- Adds an action that will be bound upon InputBind:Bind()

	assert(ActionData.ActionName, "Need ActionData.ActionName")
	assert(ActionData.FunctionToBind, "Need ActionData.FunctionToBind")
	assert(ActionData.CreateTouchButton ~= nil, "ActionData.CreateTouchButton cannot equal nil")

	self.ActionDataList[ActionData.ActionName] = ActionData
end

function InputBind:IsBound()
	-- Returns whether or not the input is already bound. 
	
	return self.IsCurrentlyBound
end

function InputBind:BindInput()
	-- Binds all the action to input.

	assert(not self.IsCurrentlyBound, "Already bound")
	self.IsCurrentlyBound = true

	for _, ActionData in pairs(self.ActionDataList) do
		if not self.BoundActionsMap[ActionData.ActionName] then
			self:BindAction(ActionData)
		end
	end
end

function InputBind:UnbindInput()
	-- Unbinds all actions associated with the interface. Used on
	-- GC most of the time.

	assert(self.IsCurrentlyBound, "Already unbound")
	self.IsCurrentlyBound = false

	for BoundActionName, ActionData in pairs(self.BoundActionsMap) do
		self:UnbindAction(BoundActionName)
	end
end



-- PRIVATE FUNCTIONS

function InputBind:BindAction(ActionData)
	--- Binds an action to the ContextActionService and to the input manager
	-- @param ActionData The data used to bind the action.
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
	assert(not self.BoundActionsMap[ActionData.ActionName], "Action is already bound")

	ActionData.CreateTouchButton = ActionData.CreateTouchButton or false;
	
	ContextActionService:BindActionToInputTypes(	
		ActionData.ActionName or error("No action name"),
		ActionData.FunctionToBind or error("No function to bind"),
		ActionData.CreateTouchButton,
		unpack(ActionData.InputTypes)
	)
	
	if ActionData.ButtonTitle then
		ContextActionService:SetTitle(ActionData.ActionName, ActionData.ButtonTitle)
	end
	
	if ActionData.ButtonImage then
		ContextActionService:SetImage(ActionData.ActionName, ActionData.ButtonImage)
	end
	
	if ActionData.InternalDescription then
		ContextActionService:SetDescription(ActionData.ActionName, ActionData.InternalDescription)
	end
	
	self:RegisterNewlyBoundAction(ActionData)
end

function InputBind:UnbindAction(BoundActionName)
	local ActionData = self.BoundActionsMap[BoundActionName]
	
	ContextActionService:UnbindAction(BoundActionName)
	self.BoundActionsMap[BoundActionName] = nil
	
	self.ActionUnbound:fire(ActionData)
end

function InputBind:RegisterNewlyBoundAction(ActionData)
	--- Registers an action (that has been bound into ContextActionService)
	--  into the controller interface so that it can later be unbound. 
	-- @param ActionName The string name of the action bound to ContextActionService.
	
	local ActionName = ActionData.ActionName	
	self.BoundActionsMap[ActionName] = ActionData
	
	self.ActionBound:fire(ActionData)
end

return InputBind