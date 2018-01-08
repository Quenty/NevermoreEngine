---
-- @classmod Scrollbar

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")
local Signal = require("Signal")

local Scrollbar = {}
Scrollbar.ClassName = "Scrollbar"
Scrollbar.__index = Scrollbar

function Scrollbar.new(gui)
	local self = setmetatable({}, Scrollbar)

	self.Gui = gui or error("No gui")
	self.DraggingBegan = Signal.new()

	self._maid = Maid.new()
	self._container = self.Gui.Parent or error("No container")

	return self
end

function Scrollbar.fromContainer(container)
	local gui = Instance.new("ImageButton")
	gui.Size = UDim2.new(1, 0, 0, 100)
	gui.Name = "ScrollBar"
	gui.BackgroundColor3 = Color3.new(0.8, 0.8, 0.8)
	gui.BorderSizePixel = 0
	gui.Image = ""
	gui.Parent = container
	gui.AutoButtonColor = false
	gui.ZIndex = container.ZIndex
	gui.Parent = container

	return Scrollbar.new(gui)
end

function Scrollbar:SetScrollingFrame(scrollingFrame)
	self._scrollingFrame = scrollingFrame or error("No scrollingFrame")
	self._model = self._scrollingFrame:GetModel()

	self._maid:GiveTask(self.Gui.InputBegan:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			local maid = self._scrollingFrame:StartScrollbarScrolling(self._container, inputObject)
			self._maid._updateMaid = maid
		end
	end))

	self:UpdateRender()
end

function Scrollbar:UpdateRender()
	if self._model.TotalContentLength > self._model.ViewSize then
		local percentSize = self._model.RenderedContentScrollPercentSize

		self.Gui.Size = UDim2.new(self.Gui.Size.X, UDim.new(percentSize, 0))

		local posY = (1-percentSize) * self._model.RenderedContentScrollPercent
		self.Gui.Position = UDim2.new(self.Gui.Position.X, UDim.new(posY, 0))

		self.Gui.Visible = true
	else
		self.Gui.Visible = false
	end
end

function Scrollbar:Destroy()
	self._maid:DoCleaning()
	self._maid = nil
	setmetatable(self, nil)
end

return Scrollbar