local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local RotatingCharacterBuilder = LoadCustomLibrary("RotatingCharacterBuilder")

--[[
class RotatingLabel

Description:
	A text label with most general properties of a textlabel, except when text is set, 
	it rotates uniformly like an old clock, animating in a satisfying way
	
	Construct with RotatingLabelBuilder.new(Template):Create()

API:
	RotatingLabel.Text = string
		Sets the text label, which it will automatically update
	RotatingLabel.Width = number
		Sets the general width of each character
	RotatingLabel.Transparency
		Sets the transparency 
	RotatingLabel.Damper
		Sets the damper of the underlying spring model
	RotatingLabel.Speed
		Sets the speed of the underlying spring model
	RotatingLabel.TextXAlignment
		Sets the alignment on the X axis. Cannot be Center.
]]

local RotatingLabel = {}
RotatingLabel.ClassName = "RotatingLabel"
RotatingLabel._Text = ""
RotatingLabel._Speed = 15
RotatingLabel._Damper = 0.85
RotatingLabel._Transparency = 0
RotatingLabel._Width = 0.5 -- A scaler of UDim2.
RotatingLabel._TextXAlignment = "Left"

function RotatingLabel.new()
	local self = setmetatable({}, RotatingLabel)

	self.Labels = setmetatable({}, {
		__index = function(Labels, Index)
			if Index == "Remove" then
				return function(_, Index)
					assert(rawget(Labels, Index), "There is no label at index" .. Index)
					rawget(Labels, Index):Destroy()
					rawset(Labels, Index, nil)
				end
			elseif Index == "Get" then
				return function(_, Index)
					-- @return The current label, or a newly constructed one

					if rawget(Labels, Index) then
						return rawget(Labels, Index)
					else
						local NewLabel = RotatingCharacterBuilder.new()
							:WithTemplate(self.Template)
							:Generate(self.Container)
							:WithCharacter(" ")
							:Create()

						NewLabel.Gui.Position = self:_getLabelPosition(Index)

						for _, PropertyName in pairs({"Transparency", "Damper", "Speed"}) do
							if NewLabel[PropertyName] ~= self[PropertyName] then
								NewLabel[PropertyName] = self[PropertyName]
							end 
						end

						rawset(Labels, Index, NewLabel)
						return NewLabel
					end
				end
			else
				return rawget(Labels, Index)
				-- error(Index .. " is not a valid member")
			end
		end;
	});

	self.BindKey = "RotatingLabel" .. tostring(self)

	return self
end

function RotatingLabel:_getLabelPosition(Index)
	if self.TextXAlignment == "Left" then
		return UDim2.new((Index-1)*self.Width, 0, 0, 0)
	else
		return UDim2.new(-self.TotalWidth + (Index-1)*self.Width, 0, 0, 0)
	end
end

function RotatingLabel:SetGui(Gui)
	self.Gui = Gui or error("No GUI")
	self.Container = self.Gui.Container
end

function RotatingLabel:SetTemplate(Template)
	self.Template = Template or error("No GUI")
end

function RotatingLabel:__index(Index)
	if Index == "Text" then
		return self._Text
	elseif Index == "TotalWidth" then
		return #self.Text * self.Width
	elseif Index == "Width" then
		return self._Width
	elseif Index == "Transparency" or Index == "Damper" or Index == "Speed" then
		return self["_" .. Index]
	elseif Index == "TextXAlignment" then
		return self._TextXAlignment
	else
		return RotatingLabel[Index]
	end
end

function RotatingLabel:__newindex(Index, Value)
	if Index == "Text" then
		if type(Value) == "number" then
			Value = tostring(Value)
		end

		assert(type(Value) == "string", "Text must be a string, got " .. type(Value))


		if self.TextXAlignment == "Right" then
			-- Shifts existing labels over in the stack so when we add more they 
			local Delta = #Value - #self.Text

			local Labels = {}

			for Index, Label in pairs(self.Labels) do
				local NewIndex = Index+Delta
				Labels[NewIndex] = Label

				-- Clean up
				if NewIndex < 1 or NewIndex > #Value then
					Label.TargetCharacter = " "
				end
				
				self.Labels[Index] = nil
			end

			for Index, Label in pairs(Labels) do
				self.Labels[Index] = Label
			end
		else
			-- Clean up past characters

			for Index = #Value+1, #self.Text do
				if self.Labels[Index] then
					self.Labels[Index].TargetCharacter = " "
				end
			end
		end

		self._Text = Value

		for Index = 1, #self.Text do
			self.Labels:Get(Index).TargetCharacter = self.Text:sub(Index, Index)
		end

 		for Index, Label in pairs(self.Labels) do
			Label.Gui.Position = self:_getLabelPosition(Index)
		end

		self:BeginUpdate()
	elseif Index == "Width" then
		self._Width = Value

		for Index, Label in pairs(self.Labels) do
			Label.Gui.Position = self:_getLabelPosition(Index)
		end
	elseif Index == "Transparency" or Index == "Damper" or Index == "Speed" then
		self["_" .. Index] = Value
		for _, Label in pairs(self.Labels) do
			Label[Index] = self[Index]
		end
	elseif Index == "TextXAlignment" then
		assert(Value == "Left" or Value == "Right", "Value must be \"Left\" or \"Right\"")

		if Value == "Left" then
			self.Container.Position = UDim2.new(0, 0, 0, 0)
		else
			self.Container.Position = UDim2.new(1, 0, 0, 0)
		end

		self._TextXAlignment = Value
		for Index, Label in pairs(self.Labels) do
			Label.Gui.Position = self:_getLabelPosition(Index)
		end
	else
		rawset(self, Index, Value)
	end
end

-- @return IsDoneUpdating
function RotatingLabel:_updateRender()
	local IsDone = true

	for Index, Label in pairs(self.Labels) do
		if Label:UpdateRender() then
			if Label.TargetCharacter == " " then
				self.Labels:Remove(Index)
			else
				Label.Value = Label.Target
				Label:UpdateRender()
			end
		else -- Label is sitll animating
			IsDone = false
		end
	end

	return IsDone
end

function RotatingLabel:_stopUpdate()
	RunService:UnbindFromRenderStep(self.BindKey)
	self.Bound = false
end

function RotatingLabel:BeginUpdate()
	if not self.Bound then
		self.Bound = true

		RunService:BindToRenderStep(self.BindKey, 2000, function()
			if self:_updateRender() then
				self:_stopUpdate()
			end
		end)
	end
end

function RotatingLabel:Destroy()
	self:_stopUpdate()
	self.BindKey = nil

	for Index, _ in pairs(self.Labels) do
		self.Labels:Remove(Index)
	end
	self.Labels = nil

	self.Gui:Destroy()
	self.Template:Destroy()

	setmetatable(self, nil)
end

return RotatingLabel