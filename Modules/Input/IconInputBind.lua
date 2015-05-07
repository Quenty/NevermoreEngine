local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local InputBind         = LoadCustomLibrary("InputBind")

-- Allows an Icon to be supported automatically from binding and unbinding by a IconProvider.
-- Kind of messy, and should probably be done in a different way.
-- @author Quenty

-- The real problem is intercepting the input. Meh. This really needs to be fixed.

local IconInputBind = {}
IconInputBind.__index = IconInputBind
IconInputBind.ClassName = "IconInputBind"
setmetatable(IconInputBind, InputBind)

function IconInputBind.new(IconProvider)
	local self = InputBind.new()
	setmetatable(self, IconInputBind)
	
	self.IconProvider = IconProvider
	
	return self
end

function IconInputBind:BindAction(ActionData)
	-- Note: Any action with a .Icon will have the icon destroyed after 0.3 seconds of unbinding. 

	local Super = getmetatable(IconInputBind)
	
	-- CONSTRUCTION (Should probably be moved?)
	if self.IconProvider and ActionData.CreateKeyIcon and not ActionData.Icon then
		-- Construct icon
		local Icon = self.IconProvider:GetLabeledKey(
			ActionData.InputTypes[1],
			ActionData.ActionName)
		ActionData.Icon = Icon
	end

	-- ANIMATION
	if ActionData.Icon then
		local Icon = ActionData.Icon

		-- Override key depression too.
		local RegularFunction = ActionData.FunctionToBind
		ActionData.FunctionToBind = function(ActionName, UserInputState, InputObject)
			if UserInputState.Name == "End" then
				Icon:SetFillTransparency(1)
			else
				Icon:SetFillTransparency(0.5)
			end
			
			RegularFunction(ActionName, UserInputState, InputObject)
		end
		
		-- Add to data
		ActionData.Icon = Icon
	end
	
	Super.BindAction(self, ActionData)
end

function IconInputBind:UnbindAction(BoundActionName)
	local Super = getmetatable(IconInputBind)
	
	
	local ActionData = self.BoundActionsMap[BoundActionName]
	if ActionData.Icon then
		local Icon = ActionData.Icon
		ActionData.Icon = nil
		
		delay(0.3, function()
			Icon:Destroy()
		end)
	end
	
	Super.UnbindAction(self, BoundActionName)
end

return IconInputBind