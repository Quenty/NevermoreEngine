local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qMath = LoadCustomLibrary("qMath")
local SpringPhysics = LoadCustomLibrary("SpringPhysics")

local MapNumber = qMath.MapNumber

-- @author Quenty
-- Intent: Fancy rotating labels

local RotatingCharacter = {}
RotatingCharacter.ClassName = "RotatingCharacter"
RotatingCharacter._Transparency = 0
RotatingCharacter.SpaceCode = 96--47 -- The key to use (ASCII) that acts as a space. So we get animations that move to this as a hidden value..

function RotatingCharacter.new(Gui)
	local self = setmetatable({}, RotatingCharacter)

	self.Gui = Gui
	self.Label = self.Gui.Label
	self.LabelTwo = self.Label.SecondLabel

	self.Spring = SpringPhysics.new()

	self.TargetCharacter = " "
	self.Character = self.TargetCharacter

	self.TransparencyList = setmetatable({}, {
		__newindex = function(self, Index, Value)
			rawset(self, Index, {
				Gui = Value;
				Default = {
					TextTransparency = Value.TextTransparency;
					TextStrokeTransparency = Value.TextStrokeTransparency;
				};
			})
		end;
	})
	self.TransparencyList[1] = self.Label
	self.TransparencyList[2] = self.LabelTwo
	self.Transparency = self.Transparency -- Force update

	return self
end

function RotatingCharacter:__index(Index)
	if Index == "Character" then
		return self:IntToChar(self.Value)
	elseif Index == "IsDoneAnimating" then
		return math.abs(self.Velocity) < 0.05 and math.abs(self.Target - self.Value) < 0.05
	elseif Index == "NextCharacter" then
		return self:IntToChar(self.Value+1) -- For rendering purposes.
	elseif Index == "Target" or Index == "Velocity" or Index == "Speed" or Index == "Position" or Index == "Value" or Index == "Damper" then
		return self.Spring[Index]
	elseif Index == "TargetCharacter" then
		return self:IntToChar(self.Target)
	elseif Index == "Transparency" then
		return self._Transparency
	elseif Index == "TransparencyMap" then
		local Default = (self.Position % 1)

		-- Adjust transparency upwards based upon velocity
		Default = MapNumber(Default, 0, 1, math.clamp(math.abs(self.Velocity*2/self.Speed), 0, 0.25), 1)

		local Modifier = (1 - self.Transparency)

		return {
			[self.Label] = Default*Modifier;
			[self.LabelTwo] = (1 - Default)*Modifier;
		}
	else
		return RotatingCharacter[Index]
	end
end

function RotatingCharacter:__newindex(Index, Value)
	if Index == "Character" then
		assert(#Value == 1, "Character must be length 1 (at) " .. #Value)
		self.Value = self:CharToInt(Value)
	elseif Index == "TargetCharacter" then
		assert(#Value == 1, "Character must be length 1 (at) " .. #Value)
		self.Target = self:CharToInt(Value)
	elseif Index == "Target" or Index == "Velocity" or Index == "Speed" or Index == "Position" or Index == "Value" or Index == "Damper" then
		self.Spring[Index] = Value
	elseif Index == "Transparency" then
		self._Transparency = Value

		-- We need to call this because if transparency updates and we hit past "IsDoneAnimating" but not past 
		-- actual position updates, the TransparencyMap is wrong.
		self:UpdatePositionRender()

		local TransparencyMap = self.TransparencyMap

		for _, Data in pairs(self.TransparencyList) do
			local Transparency = TransparencyMap[Data.Gui] or error("Gui not in transparency map");
			for PropertyName, DefaultValue in pairs(Data.Default) do
				Data.Gui[PropertyName] = MapNumber(Transparency, 0, 1, DefaultValue, 1)
			end
		end
	else
		rawset(self, Index, Value)
	end
end

function RotatingCharacter:UpdatePositionRender()
	self.Label.Text = self.Character
	self.LabelTwo.Text = self.NextCharacter
	self.Label.Position = UDim2.new(0, 0, -(self.Position % 1), 0)
end

function RotatingCharacter:UpdateRender()
	--self:UpdatePositionRender() -- Covered by setting transparency. Yeah. This is weird.
	self.Transparency = self.Transparency

	return self.IsDoneAnimating
end

function RotatingCharacter:IntToChar(Value)
	Value = math.floor(Value)
	return Value == self.SpaceCode and " " or string.char(Value)
end

function RotatingCharacter:CharToInt(Char)
	return Char == " " and self.SpaceCode or string.byte(Char)
end

function RotatingCharacter:Destroy()
	self.Gui:Destroy()
	self.Gui = nil

	setmetatable(self, nil)
end


local RotatingCharacterBuilder = {}
RotatingCharacterBuilder.__index = RotatingCharacterBuilder
RotatingCharacterBuilder.ClassName = "RotatingCharacterBuilder"

function RotatingCharacterBuilder.new()
	local self = setmetatable({}, RotatingCharacterBuilder)

	return self
end

function RotatingCharacterBuilder:WithTemplate(TextLabelTemplate)
	self.TextLabelTemplate = TextLabelTemplate

	return self
end

function RotatingCharacterBuilder:Generate(Parent)
	local Template = self.TextLabelTemplate or error("Must set TextLabelTemplate")

	local Container = Instance.new("Frame")
	Container.Name = "RotatingCharacterContainer";
	Container.ClipsDescendants = true
	Container.SizeConstraint = Enum.SizeConstraint.RelativeYY
	Container.Size = UDim2.new(1, 0, 1, 0)
	Container.BackgroundTransparency = Template.BackgroundTransparency
	Container.ZIndex = Template.ZIndex
	Container.BorderSizePixel = Template.BorderSizePixel
	Container.BackgroundColor3 = Template.BackgroundColor3

	local TextLabel = Instance.new("TextLabel")
	TextLabel.Name = "Label"
	TextLabel.BackgroundTransparency = 1
	TextLabel.Size = UDim2.new(1, 0, 1, 0)
	TextLabel.ZIndex = Template.ZIndex
	TextLabel.Font = Template.Font
	TextLabel.TextSize = Template.TextSize
	TextLabel.TextScaled = Template.TextScaled
	TextLabel.TextColor3 = Template.TextColor3
	TextLabel.TextTransparency = Template.TextTransparency
	TextLabel.TextStrokeTransparency = Template.TextStrokeTransparency
	TextLabel.TextXAlignment = Enum.TextXAlignment.Center
	TextLabel.TextYAlignment = Enum.TextYAlignment.Center
	TextLabel.Text = ""

	TextLabel.Parent = Container

	local Second = Container.Label:Clone()
	Second.Name = "SecondLabel"
	Second.Position = UDim2.new(0, 0, 1, 0)
	Second.SizeConstraint = Enum.SizeConstraint.RelativeXY
	Second.Parent = Container.Label

	Container.Parent = Parent or error("No parent")

	return self:WithGui(Container)
end

function RotatingCharacterBuilder:WithGui(Gui)
	self.Gui = Gui or error("No GUI")

	self.Char = RotatingCharacter.new(self.Gui)

	return self
end

function RotatingCharacterBuilder:WithCharacter(Char)
	self.Char.TargetCharacter = Char
	self.Char.Character = self.Char.TargetCharacter
	
	return self
end

function RotatingCharacterBuilder:Create()
	self.Char:UpdateRender()
	return self.Char or error("No character spawned")
end





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

						NewLabel.Gui.Position = self:GetLabelPosition(Index)

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

function RotatingLabel:GetLabelPosition(Index)
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
			Label.Gui.Position = self:GetLabelPosition(Index)
		end

		self:BeginUpdate()
	elseif Index == "Width" then
		self._Width = Value

		for Index, Label in pairs(self.Labels) do
			Label.Gui.Position = self:GetLabelPosition(Index)
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
			Label.Gui.Position = self:GetLabelPosition(Index)
		end
	else
		rawset(self, Index, Value)
	end
end

function RotatingLabel:UpdateRender()
	-- @return IsDoneUpdating
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

function RotatingLabel:StopUpdate()
	RunService:UnbindFromRenderStep(self.BindKey)
	self.Bound = false
end

function RotatingLabel:BeginUpdate()
	if not self.Bound then
		self.Bound = true

		RunService:BindToRenderStep(self.BindKey, 2000, function()
			if self:UpdateRender() then
				self:StopUpdate()
			end
		end)
	end
end

function RotatingLabel:Destroy()
	self:StopUpdate()
	self.BindKey = nil

	for Index, _ in pairs(self.Labels) do
		self.Labels:Remove(Index)
	end
	self.Labels = nil

	self.Gui:Destroy()
	self.Template:Destroy()

	setmetatable(self, nil)
end



local RotatingLabelBuilder = {}
RotatingLabelBuilder.ClassName = "RotatingLabelBuilder"
RotatingLabelBuilder.__index = RotatingLabelBuilder

function RotatingLabelBuilder.new(Gui)
	local self = setmetatable({}, RotatingLabelBuilder)

	if Gui then
		self:WithTemplate(Gui)
	end
	
	return self
end

function RotatingLabelBuilder:WithTemplate(Template)
	self.Template = Template

	self.Label = RotatingLabel.new()
	self.Label:SetTemplate(Template)

	local Frame = Instance.new("Frame")
	Frame.Name = Template.Name .. "_RotatingLabel"
	Frame.Size = Template.Size
	Frame.AnchorPoint = Template.AnchorPoint
	Frame.Position = Template.Position
	Frame.SizeConstraint = Template.SizeConstraint
	Frame.BackgroundTransparency = 1
	Frame.BorderSizePixel = 0

	local Container = Instance.new("Frame")
	Container.Name = "Container"
	Container.SizeConstraint = Enum.SizeConstraint.RelativeYY
	Container.Size = UDim2.new(1, 0, 1, 0)
	Container.BackgroundTransparency = 1
	
	Container.Parent = Frame
	Frame.Parent = Template.Parent

	return self:WithGui(Frame)
end

function RotatingLabelBuilder:WithGui(Gui)
	self.Label:SetGui(Gui)
	self.Label.TextXAlignment = self.Template.TextXAlignment.Name
	self.Label.Text = self.Template.Text

	self.Template.Parent = nil

	return self
end

function RotatingLabelBuilder:Create()
	self.Label:UpdateRender()

	return self.Label
end

return RotatingLabelBuilder