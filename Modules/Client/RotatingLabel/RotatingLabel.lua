--- A text label with most general properties of a textlabel, except when text is set,
-- it rotates uniformly like an old clock, animating in a satisfying way
-- @usage Construct with RotatingLabelBuilder.new(Template):Create()

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")

local RotatingCharacterBuilder = require("RotatingCharacterBuilder")

local RotatingLabel = {}
RotatingLabel.ClassName = "RotatingLabel"
RotatingLabel._text = ""
RotatingLabel._speed = 15
RotatingLabel._damper = 0.85
RotatingLabel._transparency = 0
RotatingLabel._width = 0.5 -- A scaler of UDim2.
RotatingLabel._textXAlignment = "Left"

function RotatingLabel.new()
	local self = setmetatable({}, RotatingLabel)

	self._labels = setmetatable({}, {
		__index = function(labels, index)
			if index == "Remove" then
				return function(_, index)
					assert(rawget(labels, index), "There is no label at index" .. index)
					rawget(labels, index):Destroy()
					rawset(labels, index, nil)
				end
			elseif index == "Get" then
				return function(_, index)
					-- @return The current label, or a newly constructed one

					if rawget(labels, index) then
						return rawget(labels, index)
					else
						local newLabel = RotatingCharacterBuilder.new()
							:WithTemplate(self._template)
							:Generate(self._container)
							:WithCharacter(" ")
							:Create()

						newLabel.Gui.Position = self:_getLabelPosition(index)

						for _, propertyName in pairs({"Transparency", "Damper", "Speed"}) do
							if newLabel[propertyName] ~= self[propertyName] then
								newLabel[propertyName] = self[propertyName]
							end
						end

						rawset(labels, index, newLabel)
						return newLabel
					end
				end
			else
				return rawget(labels, index)
				-- error(index .. " is not a valid member")
			end
		end;
	});

	self._bindKey = "RotatingLabel" .. tostring(self)

	return self
end

function RotatingLabel:_getLabelPosition(index)
	if self.TextXAlignment == "Left" then
		return UDim2.new((index-1)*self.Width, 0, 0, 0)
	else
		return UDim2.new(-self.TotalWidth + (index-1)*self.Width, 0, 0, 0)
	end
end

function RotatingLabel:SetGui(gui)
	self.Gui = gui or error("No GUI")
	self._container = self.Gui.Container
end

function RotatingLabel:SetTemplate(template)
	self._template = template or error("No GUI")
end

function RotatingLabel:__index(index)
	if index == "Text" then
		return self._text
	elseif index == "TotalWidth" then
		return #self.Text * self.Width
	elseif index == "Width" then
		return self._width
	elseif index == "Transparency" or index == "Damper" or index == "Speed" then
		return self["_" .. index:lower()]
	elseif index == "TextXAlignment" then
		return self._textXAlignment
	else
		return RotatingLabel[index]
	end
end

---
-- @usage
--[[
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
function RotatingLabel:__newindex(index, value)
	if index == "Text" then
		if type(value) == "number" then
			value = tostring(value)
		end

		assert(type(value) == "string", "Text must be a string, got " .. type(value))

		if self.TextXAlignment == "Right" then
			-- Shifts existing labels over in the stack so when we add more they
			local Delta = #value - #self.Text

			local labels = {}

			for index, label in pairs(self._labels) do
				local NewIndex = index+Delta
				labels[NewIndex] = label

				-- Clean up
				if NewIndex < 1 or NewIndex > #value then
					label.TargetCharacter = " "
				end

				self._labels[index] = nil
			end

			for index, label in pairs(labels) do
				self._labels[index] = label
			end
		else
			-- Clean up past characters

			for index = #value+1, #self.Text do
				if self._labels[index] then
					self._labels[index].TargetCharacter = " "
				end
			end
		end

		self._text = value

		for index = 1, #self.Text do
			self._labels:Get(index).TargetCharacter = self.Text:sub(index, index)
		end

		for index, label in pairs(self._labels) do
			label.Gui.Position = self:_getLabelPosition(index)
		end

		self:_beginUpdate()
	elseif index == "Width" then
		self._width = value

		for index, label in pairs(self._labels) do
			label.Gui.Position = self:_getLabelPosition(index)
		end
	elseif index == "Transparency" or index == "Damper" or index == "Speed" then
		self["_" .. index:lower()] = value
		for _, label in pairs(self._labels) do
			label[index] = self[index]
		end
	elseif index == "TextXAlignment" then
		assert(value == "Left" or value == "Right", "value must be \"Left\" or \"Right\"")

		if value == "Left" then
			self._container.Position = UDim2.new(0, 0, 0, 0)
		else
			self._container.Position = UDim2.new(1, 0, 0, 0)
		end

		self._textXAlignment = value
		for index, label in pairs(self._labels) do
			label.Gui.Position = self:_getLabelPosition(index)
		end
	else
		rawset(self, index, value)
	end
end

-- @return IsDoneUpdating
function RotatingLabel:UpdateRender()
	local isDone = true

	for index, label in pairs(self._labels) do
		if label:UpdateRender() then
			if label.TargetCharacter == " " then
				self._labels:Remove(index)
			else
				label.Value = label.Target
				label:UpdateRender()
			end
		else -- label is sitll animating
			isDone = false
		end
	end

	return isDone
end

function RotatingLabel:_stopUpdate()
	RunService:UnbindFromRenderStep(self._bindKey)
	self._bound = false
end

function RotatingLabel:_beginUpdate()
	if not self._bound then
		self._bound = true

		RunService:BindToRenderStep(self._bindKey, 2000, function()
			if self:UpdateRender() then
				self:_stopUpdate()
			end
		end)
	end
end

function RotatingLabel:Destroy()
	self:_stopUpdate()
	self._bindKey = nil

	for index, _ in pairs(self._labels) do
		self._labels:Remove(index)
	end
	self._labels = nil

	self.Gui:Destroy()
	self._template:Destroy()

	setmetatable(self, nil)
end

return RotatingLabel