--!nocheck
--[=[
	Character that rotates for animations
	@class RotatingCharacter
]=]

local require = require(script.Parent.loader).load(script)

local Math = require("Math")
local Spring = require("Spring")
local SpringUtils = require("SpringUtils")

local RotatingCharacter = {}
RotatingCharacter.ClassName = "RotatingCharacter"
RotatingCharacter._transparency = 0

-- The key to use (ASCII) that acts as a space. So we get animations that move to this as a hidden value.
local SPACE_CODE = 96
local SPRING_VALUES = {
	Target = true,
	Velocity = true,
	Speed = true,
	Position = true,
	Value = true,
	Damper = true,
}

function RotatingCharacter.new(Gui)
	local self = setmetatable({}, RotatingCharacter)

	self.Gui = Gui

	self._label = self.Gui.Label
	self._labelTwo = self._label.SecondLabel
	self._spring = Spring.new(0)

	self._label.TextXAlignment = Enum.TextXAlignment.Left
	self._labelTwo.TextXAlignment = Enum.TextXAlignment.Left -- hack

	self.TargetCharacter = " "
	self.Character = self.TargetCharacter

	self.TransparencyList = setmetatable({}, {
		__newindex = function(transparencyList, index, value)
			rawset(transparencyList, index, {
				Gui = value,
				Default = {
					TextTransparency = value.TextTransparency,
					TextStrokeTransparency = value.TextStrokeTransparency,
				},
			})
		end,
	})
	self.TransparencyList[1] = self._label
	self.TransparencyList[2] = self._labelTwo
	self.Transparency = self.Transparency -- Force update

	return self
end

function RotatingCharacter:__index(index)
	if index == "Character" then
		return self:_intToChar(self.Value)
	elseif index == "IsDoneAnimating" then
		return not SpringUtils.animating(self._spring)
	elseif index == "NextCharacter" then
		return self:_intToChar(self.Value + 1) -- For rendering purposes.
	elseif index == "Position" then
		local _, position = SpringUtils.animating(self._spring)
		return position
	elseif SPRING_VALUES[index] then
		return self._spring[index]
	elseif index == "TargetCharacter" then
		return self:_intToChar(self.Target)
	elseif index == "Transparency" then
		return self._transparency
	elseif index == "TransparencyMap" then
		local default = (self.Position % 1)

		-- Adjust transparency upwards based upon velocity
		default = Math.map(default, 0, 1, math.clamp(math.abs(self.Velocity * 2 / self.Speed), 0, 0.25), 1)

		local transparency = self.Transparency

		return {
			[self._label] = Math.map(default, 0, 1, transparency, 1),
			[self._labelTwo] = Math.map(default, 1, 0, transparency, 1),
		}
	else
		return RotatingCharacter[index]
	end
end

function RotatingCharacter:__newindex(index, value)
	if index == "Character" then
		assert(#value == 1, "Character must be length 1 (at) " .. #value)
		self.Value = self:CharToInt(value)
	elseif index == "TargetCharacter" then
		assert(#value == 1, "Character must be length 1 (at) " .. #value)
		self.Target = self:CharToInt(value)
	elseif SPRING_VALUES[index] then
		self._spring[index] = value
	elseif index == "Transparency" then
		self._transparency = value

		-- We need to call this because if transparency updates and we hit past "IsDoneAnimating" but not past
		-- actual d updates, the TransparencyMap is wrong.
		self:UpdatePositionRender()

		local transparencyMap = self.TransparencyMap

		for _, data in self.TransparencyList do
			local transparency = transparencyMap[data.Gui] or error("Gui not in transparency map")
			for property, propValue in data.Default do
				data.Gui[property] = Math.map(transparency, 0, 1, propValue, 1)
			end
		end
	else
		rawset(self, index, value)
	end
end

function RotatingCharacter:UpdatePositionRender()
	self._label.Text = self.Character
	self._labelTwo.Text = self.NextCharacter
	self._label.Position = UDim2.new(0, 0, -(self.Position % 1), 0)
end

function RotatingCharacter:UpdateRender()
	--self:UpdatePositionRender() -- Covered by setting transparency. Yeah. This is weird.
	self.Transparency = self.Transparency

	return self.IsDoneAnimating
end

function RotatingCharacter:_intToChar(value)
	value = math.floor(value)
	return value == SPACE_CODE and " " or string.char(value)
end

function RotatingCharacter:CharToInt(char)
	return char == " " and SPACE_CODE or string.byte(char)
end

function RotatingCharacter:Destroy()
	self.Gui:Destroy()
	self.Gui = nil
	setmetatable(self, nil)
end

return RotatingCharacter