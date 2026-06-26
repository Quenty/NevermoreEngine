--!strict
--[=[
	Creates an inertia based scrolling frame that is animated and has inertia frames
	Alternative to a Roblox ScrollingFrame with inertia scrolling and complete control over behavior and style.

	@deprecated 1.0.0
	@class ScrollingFrame
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Maid = require("Maid")
local SCROLL_TYPE = require("SCROLL_TYPE")
local ScrollModel = require("ScrollModel")
local Table = require("Table")

local ScrollingFrame = {}
ScrollingFrame.ClassName = "ScrollingFrame"
ScrollingFrame.__index = ScrollingFrame

export type ScrollType = {
	Direction: string,
}

export type ScrollingFrameOptions = {
	OnClick: ((inputObject: InputObject) -> ())?,
}

export type ScrollingFrame = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		Gui: GuiObject,
		_container: GuiObject,
		_scrollType: ScrollType,
		_scrollbars: { any },
		_model: ScrollModel.ScrollModel,
	},
	{} :: typeof({ __index = ScrollingFrame })
))

--[=[
	Creates a new ScrollingFrame which can be used. Prefer Container.Active = true so scroll wheel works.
	Container should be in a Frame with ClipsDescendants = true

	@param gui BaseGui -- Gui to use
	@return ScrollingFrame
]=]
function ScrollingFrame.new(gui: GuiObject): ScrollingFrame
	local self: ScrollingFrame = setmetatable({} :: any, ScrollingFrame)

	self._maid = Maid.new()
	self.Gui = gui or error("No Gui")
	self._container = (self.Gui.Parent or error("No container")) :: GuiObject
	self._scrollType = SCROLL_TYPE.Vertical

	self._scrollbars = {}
	self._model = ScrollModel.new()

	self._maid:GiveTask(self:BindInput(gui))
	self._maid:GiveTask(self:BindInput(self._container))

	self._maid:GiveTask(self._container:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_updateScrollerSize()
		self:_freeScroll(true)
	end))

	self._maid:GiveTask(self.Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_updateScrollerSize()
		self:_freeScroll(true)
	end))

	self:_updateScrollerSize()
	self:_updateRender()

	return self
end

-- Sets the scroll type for the frame
function ScrollingFrame.SetScrollType(self: ScrollingFrame, scrollType: ScrollType): ()
	assert(Table.contains(SCROLL_TYPE :: any, scrollType))
	self._scrollType = scrollType
end

function ScrollingFrame.AddScrollbar(self: ScrollingFrame, scrollbar: any): ()
	assert(scrollbar, "Bad scrollbar")
	scrollbar:SetScrollingFrame(self)

	table.insert(self._scrollbars, scrollbar)
	self._maid[scrollbar] = scrollbar
end

function ScrollingFrame.RemoveScrollbar(self: ScrollingFrame, scrollbar: any): ()
	local index = Table.getIndex(self._scrollbars, scrollbar)
	if index then
		table.remove(self._scrollbars, index)
		self._maid[scrollbar] = nil
	end
end

-- Scrolls to the position in pixels offset
function ScrollingFrame.ScrollTo(self: ScrollingFrame, position: number, doNotAnimate: boolean?): ()
	self._model.Target = position
	if doNotAnimate then
		(self._model :: any).position = self._model.Target
		self._model.Velocity = 0
	end
end

-- Scrolls to the top
function ScrollingFrame.ScrollToTop(self: ScrollingFrame, doNotAnimate: boolean?): ()
	self:ScrollTo(self._model.Min, doNotAnimate)
end

-- Scrolls to the bottom
function ScrollingFrame.ScrollToBottom(self: ScrollingFrame, doNotAnimate: boolean?): ()
	self:ScrollTo(self._model.Max, doNotAnimate)
end

function ScrollingFrame.GetModel(self: ScrollingFrame): ScrollModel.ScrollModel
	return self._model
end

function ScrollingFrame._updateScrollerSize(self: ScrollingFrame): ()
	self._model.TotalContentLength = (self.Gui.AbsoluteSize :: any)[self._scrollType.Direction]
	self._model.ViewSize = (self._container.AbsoluteSize :: any)[self._scrollType.Direction]
end

function ScrollingFrame._updateRender(self: ScrollingFrame): ()
	if self._scrollType == SCROLL_TYPE.Vertical then
		self.Gui.Position = UDim2.new(self.Gui.Position.X, UDim.new(0, self._model.BoundedRenderPosition))
	elseif self._scrollType == SCROLL_TYPE.Horizontal then
		self.Gui.Position = UDim2.new(UDim.new(0, self._model.BoundedRenderPosition), self.Gui.Position.Y)
	else
		error("[ScrollingFrame] - Bad ScrollType")
	end

	for _, scrollbar in self._scrollbars do
		if scrollbar.Destroy then
			scrollbar:UpdateRender()
		else
			warn("[ScrollingFrame] - Scrollbar is destroyed")
		end
	end
end

function ScrollingFrame.StopDrag(self: ScrollingFrame): ()
	local position = self._model.Position

	if self._model:GetDisplacementPastBounds(position) == 0 then
		if self._model.Velocity > 0 then
			self._model.Target = math.max(self._model.Target, position + self._model.Velocity * 0.5)
		else
			self._model.Target = math.min(self._model.Target, position + self._model.Velocity * 0.5)
		end
	end

	self:_freeScroll()
end

-- Scrolls until model is at rest
function ScrollingFrame._freeScroll(self: ScrollingFrame, lowPriority: boolean?): ()
	if lowPriority and self._maid._updateMaid then
		return
	end

	local maid = Maid.new()

	self:_updateRender()
	maid:GiveTask(RunService.Heartbeat:Connect(function()
		self:_updateRender()
		if self._model.AtRest then
			self._maid._updateMaid = nil
		end
	end))

	self._maid._updateMaid = maid
end

--
-- @param[opt=1] strength
function ScrollingFrame._getVelocityTracker(self: ScrollingFrame, strength: number?): () -> ()
	local actualStrength = strength or 1
	self._model.Velocity = 0

	local lastUpdate = tick()
	local lastPos = self._model.Position

	return function(): ()
		local pos = self._model.Position
		local elapsed = tick() - lastUpdate
		local delta = lastPos - pos

		if elapsed == 0 then
			elapsed = 0.03
		end

		self._model.Velocity = self._model.Velocity - (delta / elapsed) * actualStrength
		lastPos = pos
		lastUpdate = tick()
	end
end

function ScrollingFrame._getInputProcessor(self: ScrollingFrame, inputBeganObject: InputObject): (InputObject) -> number
	local startPos = self._model.Position
	local updateVelocity = self:_getVelocityTracker()
	local originalPos = inputBeganObject.Position

	return function(inputObject: InputObject): number
		local distance = ((inputObject.Position - originalPos) :: any)[self._scrollType.Direction]
		local pos = startPos - distance
		self._model.Position = pos
		self._model.Target = pos

		self:_updateRender()
		updateVelocity()

		return distance
	end
end

-- Binds input to a specific GUI
-- @return maid Maid -- To cleanup inputs
function ScrollingFrame.BindInput(self: ScrollingFrame, gui: GuiObject, options: ScrollingFrameOptions?): Maid.Maid
	local maid = Maid.new()

	maid:GiveTask(gui.InputBegan:Connect(function(inputObject)
		self:StartScrolling(inputObject, options)
	end))

	maid:GiveTask(gui.InputChanged:Connect(function(inputObject)
		if gui.Active and inputObject.UserInputType == Enum.UserInputType.MouseWheel then
			self._model.Target = self._model.Target - (inputObject.Position :: any).z * 80
			self:_freeScroll()
		end
	end))

	self._maid:GiveTask(maid)
	return maid
end

function ScrollingFrame.StartScrolling(self: ScrollingFrame, inputBeganObject: InputObject, options: ScrollingFrameOptions?): ()
	if inputBeganObject.UserInputState ~= Enum.UserInputState.Begin then
		-- Touch events moving into GUIs occur sometimes
		return
	end

	if
		inputBeganObject.UserInputType == Enum.UserInputType.MouseButton1
		or inputBeganObject.UserInputType == Enum.UserInputType.Touch
	then
		local maid = Maid.new()

		local startTime = tick()
		local totalScrollDistance = 0
		local processInput = self:_getInputProcessor(inputBeganObject)

		if inputBeganObject.UserInputType == Enum.UserInputType.MouseButton1 then
			maid:GiveTask(UserInputService.InputChanged:Connect(function(inputObject, _)
				if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
					totalScrollDistance = totalScrollDistance + math.abs(processInput(inputObject))
				end
			end))
		elseif inputBeganObject.UserInputType == Enum.UserInputType.Touch then
			maid:GiveTask(UserInputService.InputChanged:Connect(function(inputObject, _)
				if inputObject.UserInputType == Enum.UserInputType.Touch then
					totalScrollDistance = totalScrollDistance + math.abs(processInput(inputObject))
				end
			end))
		end

		maid:GiveTask(function()
			self:_updateRender()
			if options and options.OnClick then
				local elapsedTime = tick() - startTime
				local consideredClick = (elapsedTime <= 0.05) or (totalScrollDistance < 1)
				if consideredClick then
					options.OnClick(inputBeganObject)
				end
			end
		end)

		maid:GiveTask(UserInputService.InputEnded:Connect(function(inputObject: InputObject, _)
			if inputObject == inputBeganObject then
				self:StopDrag()
			end
		end))

		maid:GiveTask(UserInputService.WindowFocusReleased:Connect(function()
			self:StopDrag()
		end))

		self._maid._updateMaid = maid
	end
end

function ScrollingFrame.StartScrollbarScrolling(self: ScrollingFrame, scrollbarContainer: GuiObject, inputBeganObject: InputObject): Maid.Maid
	assert(scrollbarContainer, "Bad scrollbarContainer")
	assert(inputBeganObject, "Bad inputBeganObject")

	local maid = Maid.new()

	local startPosition = inputBeganObject.Position
	local startPercent = self._model.ContentScrollPercent
	local updateVelocity = self:_getVelocityTracker(0.25)

	maid:GiveTask(UserInputService.InputChanged:Connect(function(inputObject: InputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			local direction = self._scrollType.Direction
			local offset = ((inputObject.Position - startPosition) :: any)[direction]
			local percent = offset
				/ ((scrollbarContainer.AbsoluteSize :: any)[direction] * (1 - self._model.ContentScrollPercentSize))
			self._model.ContentScrollPercent = startPercent + percent
			self._model.TargetContentScrollPercent = self._model.ContentScrollPercent

			self:_updateRender()
			updateVelocity()
		end
	end))

	maid:GiveTask(UserInputService.InputEnded:Connect(function(inputObject: InputObject)
		if inputObject == inputBeganObject then
			self:StopDrag()
		end
	end))

	self._maid._updateMaid = maid

	return maid
end

function ScrollingFrame.Destroy(self: ScrollingFrame): ()
	self._maid:DoCleaning();
	(self :: any)._maid = nil
	setmetatable(self :: any, nil)
end

return ScrollingFrame
