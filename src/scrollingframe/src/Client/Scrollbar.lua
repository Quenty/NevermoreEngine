--!strict
--[=[
	@class Scrollbar
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local SCROLL_TYPE = require("SCROLL_TYPE")
local ScrollModel = require("ScrollModel")
local Signal = require("Signal")
local Table = require("Table")

type ScrollType = typeof(SCROLL_TYPE.Vertical)

-- ScrollingFrame is still nonstrict and exports no type; type the surface we use.
type ScrollingFrameLike = {
	GetModel: (self: ScrollingFrameLike) -> ScrollModel.ScrollModel,
	StartScrollbarScrolling: (self: ScrollingFrameLike, scrollbarContainer: Instance, inputBeganObject: InputObject) -> Maid.Maid,
}

local Scrollbar = {}
Scrollbar.ClassName = "Scrollbar"
Scrollbar.__index = Scrollbar

export type Scrollbar = typeof(setmetatable(
	{} :: {
		Gui: GuiObject,
		DraggingBegan: Signal.Signal<()>,
		_maid: Maid.Maid,
		_container: Instance,
		_scrollType: ScrollType,
		_scrollingFrame: ScrollingFrameLike,
		_model: ScrollModel.ScrollModel,
	},
	{} :: typeof({ __index = Scrollbar })
))

function Scrollbar.new(gui: GuiObject, scrollType: ScrollType?): Scrollbar
	local self: Scrollbar = setmetatable({} :: any, Scrollbar)

	self.Gui = gui or error("No gui")
	self.DraggingBegan = Signal.new()

	self._maid = Maid.new()
	self._container = self.Gui.Parent or error("No container")
	self._scrollType = scrollType or SCROLL_TYPE.Vertical

	return self
end

function Scrollbar.fromContainer(container: GuiObject, scrollType: ScrollType?): Scrollbar
	local gui = Instance.new("ImageButton")
	gui.Size = UDim2.fromScale(1, 1)
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

function Scrollbar.SetScrollType(self: Scrollbar, scrollType: ScrollType): ()
	assert(Table.contains(SCROLL_TYPE, scrollType))
	self._scrollType = scrollType
end

function Scrollbar.SetScrollingFrame(self: Scrollbar, scrollingFrame: ScrollingFrameLike): ()
	self._scrollingFrame = scrollingFrame or error("No scrollingFrame")
	self._model = self._scrollingFrame:GetModel()

	self._maid:GiveTask(self.Gui.InputBegan:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self._maid._updateMaid = self._scrollingFrame:StartScrollbarScrolling(self._container, inputObject)
		end
	end))

	self:UpdateRender()
end

function Scrollbar.UpdateRender(self: Scrollbar): ()
	if self._model.TotalContentLength > self._model.ViewSize then
		local percentSize = self._model.RenderedContentScrollPercentSize
		local pos = (1 - percentSize) * self._model.RenderedContentScrollPercent

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

function Scrollbar.Destroy(self: Scrollbar): ()
	self._maid:DoCleaning();
	(self :: any)._maid = nil
	setmetatable(self :: any, nil)
end

return Scrollbar
