--[=[
	@class Scrollbar
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local SCROLL_TYPE = require("SCROLL_TYPE")
local Signal = require("Signal")
local Table = require("Table")

local Scrollbar = {}
Scrollbar.ClassName = "Scrollbar"
Scrollbar.__index = Scrollbar

function Scrollbar.new(gui, scrollType)
	local self = setmetatable({}, Scrollbar)

	self.Gui = gui or error("No gui")
	self.DraggingBegan = Signal.new()

	self._maid = Maid.new()
	self._container = self.Gui.Parent or error("No container")
	self._scrollType = scrollType or SCROLL_TYPE.Vertical

	return self
end

function Scrollbar.fromContainer(container, scrollType)
	local gui = Instance.new("ImageButton")
	gui.Size = UDim2.new(1, 0, 1, 0)
	gui.Name = "ScrollBar"
	gui.BackgroundColor3 = Color3.new(0.8, 0.8, 0.8)
	gui.BorderSizePixel = 0
	gui.Image = ""
	gui.Parent = container
	gui.AutoButtonColor = false
	gui.ZIndex = container.ZIndex
	gui.Parent = container

	return Scrollbar.new(gui, scrollType)
end

function Scrollbar:SetScrollType(scrollType)
	assert(Table.contains(SCROLL_TYPE, scrollType))
	self._scrollType = scrollType
end

function Scrollbar:SetScrollingFrame(scrollingFrame)
	self._scrollingFrame = scrollingFrame or error("No scrollingFrame")
	self._model = self._scrollingFrame:GetModel()

	self._maid:GiveTask(self.Gui.InputBegan:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self._maid._updateMaid = self._scrollingFrame:StartScrollbarScrolling(self._container, inputObject)
		end
	end))

	self:UpdateRender()
end

function Scrollbar:UpdateRender()
	if self._model.TotalContentLength > self._model.ViewSize then
		local percentSize = self._model.RenderedContentScrollPercentSize
		local pos = (1-percentSize) * self._model.RenderedContentScrollPercent

		if self._scrollType == SCROLL_TYPE.Vertical then
			self.Gui.Size = UDim2.new(self.Gui.Size.X, UDim.new(percentSize, 0))
			self.Gui.Position = UDim2.new(self.Gui.Position.X, UDim.new(pos, 0))
		elseif self._scrollType == SCROLL_TYPE.Horizontal then
			self.Gui.Size = UDim2.new(UDim.new(percentSize, 0), self.Gui.Size.Y)
			self.Gui.Position = UDim2.new(UDim.new(pos, 0), self.Gui.Position.Y)
		else
			error("[Scrollbar] - Bad ScrollType")
		end

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