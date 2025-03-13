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
local ScrollModel = require("ScrollModel")
local SCROLL_TYPE = require("SCROLL_TYPE")
local Table = require("Table")

local ScrollingFrame = {}
ScrollingFrame.ClassName = "ScrollingFrame"
ScrollingFrame.__index = ScrollingFrame

--[=[
	Creates a new ScrollingFrame which can be used. Prefer Container.Active = true so scroll wheel works.
	Container should be in a Frame with ClipsDescendants = true

	@param gui BaseGui -- Gui to use
	@return ScrollingFrame
]=]
function ScrollingFrame.new(gui)
	local self = setmetatable({}, ScrollingFrame)

	self._maid = Maid.new()
	self.Gui = gui or error("No Gui")
	self._container = self.Gui.Parent or error("No container")
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
function ScrollingFrame:SetScrollType(scrollType)
	assert(Table.contains(SCROLL_TYPE, scrollType))
	self._scrollType = scrollType
end

function ScrollingFrame:AddScrollbar(scrollbar)
	assert(scrollbar, "Bad scrollbar")
	scrollbar:SetScrollingFrame(self)

	table.insert(self._scrollbars, scrollbar)
	self._maid[scrollbar] = scrollbar
end

function ScrollingFrame:RemoveScrollbar(scrollbar)
	local index = Table.getIndex(self._scrollbars, scrollbar)
	if index then
		table.remove(self._scrollbars, index)
		self._maid[scrollbar] = nil
	end
end

-- Scrolls to the position in pixels offset
function ScrollingFrame:ScrollTo(position, doNotAnimate: boolean?)
	self._model.Target = position
	if doNotAnimate then
		self._model.position = self._model.Target
		self._model.Velocity = 0
	end
end

-- Scrolls to the top
function ScrollingFrame:ScrollToTop(doNotAnimate: boolean?)
	self:ScrollTo(self._model.Min, doNotAnimate)
end

-- Scrolls to the bottom
function ScrollingFrame:ScrollToBottom(doNotAnimate: boolean?)
	self:ScrollTo(self._model.Max, doNotAnimate)
end

function ScrollingFrame:GetModel()
	return self._model
end

function ScrollingFrame:_updateScrollerSize()
	self._model.TotalContentLength = self.Gui.AbsoluteSize[self._scrollType.Direction]
	self._model.ViewSize = self._container.AbsoluteSize[self._scrollType.Direction]
end

function ScrollingFrame:_updateRender()
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

function ScrollingFrame:StopDrag()
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
function ScrollingFrame:_freeScroll(lowPriority)
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
function ScrollingFrame:_getVelocityTracker(strength)
	strength = strength or 1
	self._model.Velocity = 0

	local lastUpdate = tick()
	local lastPos = self._model.Position

	return function()
		local pos = self._model.Position
		local elapsed = tick() - lastUpdate
		local delta = lastPos - pos

		if elapsed == 0 then
			elapsed = 0.03
		end

		self._model.Velocity = self._model.Velocity - (delta / elapsed) * strength
		lastPos = pos
		lastUpdate = tick()
	end
end

function ScrollingFrame:_getInputProcessor(inputBeganObject: InputObject)
	local startPos = self._model.Position
	local updateVelocity = self:_getVelocityTracker()
	local originalPos = inputBeganObject.Position

	return function(inputObject: InputObject)
		local distance = (inputObject.Position - originalPos)[self._scrollType.Direction]
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
function ScrollingFrame:BindInput(gui, options)
	local maid = Maid.new()

	maid:GiveTask(gui.InputBegan:Connect(function(inputObject)
		self:StartScrolling(inputObject, options)
	end))

	maid:GiveTask(gui.InputChanged:Connect(function(inputObject)
		if gui.Active and inputObject.UserInputType == Enum.UserInputType.MouseWheel then
			self._model.Target = self._model.Target - inputObject.Position.z * 80
			self:_freeScroll()
		end
	end))

	self._maid:GiveTask(maid)
	return maid
end

function ScrollingFrame:StartScrolling(inputBeganObject, options)
	if inputBeganObject.UserInputState ~= Enum.UserInputState.Begin then
		-- Touch events moving into GUIs occur sometimes
		return
	end

	if inputBeganObject.UserInputType == Enum.UserInputType.MouseButton1
		or inputBeganObject.UserInputType == Enum.UserInputType.Touch then

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

		maid:GiveTask(UserInputService.InputEnded:Connect(function(inputObject, _)
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

function ScrollingFrame:StartScrollbarScrolling(scrollbarContainer, inputBeganObject)
	assert(scrollbarContainer, "Bad scrollbarContainer")
	assert(inputBeganObject, "Bad inputBeganObject")

	local maid = Maid.new()

	local startPosition = inputBeganObject.Position
	local startPercent = self._model.ContentScrollPercent
	local updateVelocity = self:_getVelocityTracker(0.25)

	maid:GiveTask(UserInputService.InputChanged:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			local direction = self._scrollType.Direction
			local offset = (inputObject.Position - startPosition)[direction]
			local percent = offset / (scrollbarContainer.AbsoluteSize[direction] * (1 - self._model.ContentScrollPercentSize))
			self._model.ContentScrollPercent = startPercent + percent
			self._model.TargetContentScrollPercent = self._model.ContentScrollPercent

			self:_updateRender()
			updateVelocity()
		end
	end))

	maid:GiveTask(UserInputService.InputEnded:Connect(function(inputObject)
		if inputObject == inputBeganObject then
			self:StopDrag()
		end
	end))

	self._maid._updateMaid = maid

	return maid
end

function ScrollingFrame:Destroy()
	self._maid:DoCleaning()
	self._maid = nil
	setmetatable(self, nil)
end

return ScrollingFrame