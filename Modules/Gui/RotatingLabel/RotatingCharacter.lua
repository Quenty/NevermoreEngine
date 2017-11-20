local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qMath = LoadCustomLibrary("qMath")
local Spring = LoadCustomLibrary("Spring")

local MapNumber = qMath.MapNumber

local RotatingCharacter = {}
RotatingCharacter.ClassName = "RotatingCharacter"
RotatingCharacter._Transparency = 0
RotatingCharacter.SpaceCode = 96 -- The key to use (ASCII) that acts as a space. So we get animations that move to this as a hidden value..

function RotatingCharacter.new(Gui)
	local self = setmetatable({}, RotatingCharacter)

	self.Gui = Gui
	self.Label = self.Gui.Label
	self.LabelTwo = self.Label.SecondLabel

	self.Spring = Spring.new(0)

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

return RotatingCharacter