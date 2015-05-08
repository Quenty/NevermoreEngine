local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local MakeMaid          = LoadCustomLibrary("Maid").MakeMaid

-- @author Quenty
--- An extra of a BindableAction that links a LabeledKeyIcon and a BindableAction

local BindedIcon = {}
BindedIcon.__index = BindedIcon
BindedIcon.ClassName = "BindedIcon"

function BindedIcon.new(Icon)
	-- @param Icon, A LabeledKeyIcon (or KeyIcon), that will be pushed upon the IconBar
	-- Note: Must call :SetBindableAction(BindableAction) to get this to work.

	local self = {}
	setmetatable(self, BindedIcon)

	-- PRIVATE
	self.Maid  = MakeMaid()
	self.Icon  = Icon or error("No icon sent, need icon")

	return self
end

function BindedIcon:SetBindableAction(BindableAction)
	assert(BindableAction, "Need to send BindableAction")
	assert(not self.BindableAction, "Already have BindableAction")

	self.BindableAction = BindableAction

	self.BindableAction:BindFunction("_UpdateIcon", function(ActionName, InputState, InputObject)
		if InputState.Name == "Begin" then
			self.Icon:SetFillTransparency(0.5)
		elseif InputState.Name == "End" then
			self.Icon:SetFillTransparency(1)
		end
	end)
end

function BindedIcon:Destroy()
	-- Disconnects events
	setmetatable(self, nil)

	self.BindableAction:UnbindFunction("_UpdateIcon")
	self.Maid:DoCleaning()

	self.Icon:Destroy()
end






local BindedBarIcon = {}
BindedBarIcon.__index = BindedBarIcon
BindedBarIcon.ClassName = "BindedBarIcon"
setmetatable(BindedBarIcon, BindedIcon)

function BindedBarIcon.new(Icon)
	local self = BindedIcon.new(Icon)
	setmetatable(self, BindedBarIcon)

	self.OnBar = false

	return self
end

function BindedBarIcon.FromProviderAndAction(IconProvider, Action, IconBar)
	-- Parents the icon to the IconProvider:GetIconBar()
	-- @param [IconBar] Optional

	IconBar = IconBar or IconProvider:GetIconBar()

	local Icon = IconProvider:GetLabeledKey(
		Action:GetInputTypes()[1],
		Action:GetName(),
		IconBar)
			
	local NewBind = BindedBarIcon.new(Icon)
	NewBind:SetBindableAction(Action)
	NewBind:SetIconBar(IconBar)

	return NewBind
end


function BindedBarIcon:PopOffBar(AnimationTime)
	--- Pops the icon onto the current bar.
	-- @param [AnimationTime] Number [0, infinity), time to animate
	
	assert(self.OnBar, "Icon must be on bar for this happen")

	self.IconBar:RemoveIcon(self.Icon, AnimationTime)
	self.OnBar = false
end

function BindedBarIcon:PushOnBar(AnimationTime)
	--- 
	-- @param [AnimationTime] Number [0, infinity), time to animate

	self.IconBar:AddIcon(self.Icon, AnimationTime)
	self.OnBar = true
end

function BindedBarIcon:RemoveIconBar()
	if self.OnBar then
		self:PopOffBar()
	end

	self.IconBar = nil
end

function BindedBarIcon:SetIconBar(IconBar)
	assert(IconBar, "Must send IconBar")

	if self.IconBar then
		self:RemoveIconBar()
	end

	self.IconBar = IconBar

	if self.BindableAction:IsBound() then
		self:PushOnBar()
	end
end

function BindedBarIcon:SetBindableAction(BindableAction)
	assert(BindableAction, "Need to send BindableAction")

	local Super = getmetatable(BindedBarIcon)

	-- EVENTS
	self.Maid.Bound = BindableAction.Bound:connect(function()
		if not self.OnBar and self.IconBar then
			self:PushOnBar()
		end
	end)

	self.Maid.Unbound = BindableAction.Unbound:connect(function()
		if self.OnBar and self.IconBar then
			self:PopOffBar()
		end
	end)

	Super.SetBindableAction(self, BindableAction)
end

function BindedBarIcon:Destroy()
	local Super = getmetatable(BindedBarIcon)

	if self.OnBar then
		self:PopOffBar()
	end

	Super.Destroy(self)
end

return BindedBarIcon