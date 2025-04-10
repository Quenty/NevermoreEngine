--[=[
	A group of utility functions to be used to help create visual effectcs with ROBLOX GUIs

	@deprecated 2.3.1
	@class qGUI
]=]

local RunService = game:GetService("RunService")

local qGUI = {}

function qGUI.PointInBounds(frame: Frame, x: number, y: number): boolean
	local position = frame.AbsolutePosition
	local size = frame.AbsoluteSize

	local top = position.Y
	local bottom = position.Y + size.Y
	local left = position.X
	local right = position.X + size.X

	return y > top and y < bottom and x > left and x < right
end

function qGUI.MouseOver(mouse: Mouse, frame: Frame): boolean
	return qGUI.PointInBounds(frame, mouse.X, mouse.Y)
end

-- @param updateFunction()
-- @return ShouldStop, if true, will stop updating
-- @return StartUpdate()
local function createYieldedUpdate(updateFunction: () -> ())
	local animationId = 0
	local lastUpdatePoint = -1 -- If it's -1, no active thread.

	-- Increments the animationId and returns a new updateFunction
	-- to be bound into RenderStep
	local function getNewUpdateFunction(renderStepKey: string)
		local localAnimationId = animationId + 1
		animationId = localAnimationId

		-- Note that we're now updating.
		lastUpdatePoint = tick()

		-- Intended to be called each RenderStep. Will unbind itself if the updateFunction fails
		-- or a new update function is generated
		return function()
			lastUpdatePoint = tick()

			if updateFunction() or (animationId ~= localAnimationId) then
				RunService:UnbindFromRenderStep(renderStepKey)

				if animationId == localAnimationId then
					lastUpdatePoint = -1
				end
			end
		end
	end

	-- Calculates the time since the last update function was called
	-- Used to determine if a new update function should be generated, since clients tend to
	-- kill threads when local scripts are GCed
	local function timeSinceUpdate(): number
		return tick() - lastUpdatePoint
	end

	local function shouldStartUpdate(): boolean
		return lastUpdatePoint == -1 -- In this case, we have no active threads
			or timeSinceUpdate() > 0.1 -- In this case, our presumed active thread is dead.
	end

	-- Starts an update thread, potentialy removing the old one.
	local function startNewThread()
		local renderStepKey = "TweenTransparencyOnGuis" .. tostring(updateFunction) .. tick()
		RunService:BindToRenderStep(renderStepKey, 2000, getNewUpdateFunction(renderStepKey))
	end

	-- Starts the tween
	return function()
		if shouldStartUpdate() then
			startNewThread()
		end
	end
end

-- Creates a tweener that only runs when it's updating with a set properties system.
-- @param function `setProperties`
-- setProperties(Gui, Percent, StartProperties, NewProperties)
-- @param Gui The Gui to set properties on
-- @param Percent Number [0, 1] of properties to set
-- @param StartProperties The properties we started with
-- @param NewProperties The properties we ended with
-- @return
local function makePropertyTweener(setProperties)
	local guiMap: { [GuiBase]: any } = {} -- [Gui] = TweenData

	local function GetTweenData(Gui, NewProperties, Duration)
		-- Returns new tween data for the GUI in question

		local StartProperties = {}
		local EndProperties = {}

		-- Copy data into the table
		for index, Value in NewProperties do
			if Gui[index] ~= Value then
				StartProperties[index] = Gui[index]
				EndProperties[index] = Value
			end
		end

		return {
			StartTime = tick(),
			Duration = Duration,
			StartProperties = StartProperties,
			NewProperties = EndProperties,
		}
	end

	local StartRenderStepUpdater = createYieldedUpdate(function()
		-- Update function that will be called each second

		local tick = tick()
		local ShouldStop = true

		for Gui, TweenState in next, guiMap do
			if Gui:IsDescendantOf(game) then
				local TimeElapsed = tick - TweenState.StartTime

				if TimeElapsed > TweenState.Duration then -- Then we end it.
					setProperties(Gui, 1, TweenState.StartProperties, TweenState.NewProperties)
					guiMap[Gui] = nil
				else
					setProperties(
						Gui,
						TimeElapsed / TweenState.Duration,
						TweenState.StartProperties,
						TweenState.NewProperties
					)
					ShouldStop = false
				end
			else
				guiMap[Gui] = nil
			end
		end

		return ShouldStop
	end)

	-- A tweening function to begin tweening on a Gui element
	-- @param Gui The GUI to tween the Transparency's upon
	-- @param NewProperties The properties to be changed. It will take the current
	--                      properties and tween to the new ones. This table should be
	--                      setup so {index = NewValue} that is, for example,
	--                      {TextTransparency = 1}.
	-- @param Duration The amount of time to spend transitioning.
	return function(Gui: GuiBase, NewProperties, Duration: number)

		if Duration <= 0 then
			setProperties(Gui, 1, NewProperties, NewProperties)
		else
			guiMap[Gui] = GetTweenData(Gui, NewProperties, Duration)
			StartRenderStepUpdater()
		end

		-- A tweening function to manually terminate tweening on a Gui element
		-- @param Gui The GUI to stop tweening
	end, function(Gui)
		guiMap[Gui] = nil
	end
end

-- TweenTransparency(Gui, NewProperties, Time)
-- Tween's the Transparency values in a GUI,
-- @param Gui The GUI to tween the Transparency's upon
-- @param NewProperties The properties to be changed. It will take the current
--                      properties and tween to the new ones. This table should be
--                      setup so {index = NewValue} that is, for example,
--                      {TextTransparency = 1}.
-- @param Time The amount of time to spend transitioning.
local TweenTransparency, StopTransparencyTween = makePropertyTweener(
	function(Gui: any, percent: number, startProperties, newProperties)
		for index, endValue in next, newProperties do
			local StartProperty = startProperties[index]
			Gui[index] = StartProperty + (endValue - StartProperty) * percent
		end
	end
)

qGUI.TweenTransparency = TweenTransparency
qGUI.StopTransparencyTween = StopTransparencyTween

-- TweenColor3(Gui, NewProperties, Time)
-- Tween's the Color3 values in a GUI,
-- @param Gui The GUI to tween the Color3's upon
-- @param NewProperties The properties to be changed. It will take the current
--                      properties and tween to the new ones. This table should be
--                      setup so {index = NewValue} that is, for example,
--                      {BackgroundColor3 = Color3.new(1, 1, 1)}.
-- @param Duration The amount of time to spend transitioning.
local TweenColor3, StopColor3Tween
do
	local function LerpNumber(valueOne: number, valueTwo: number, alpha: number): number
		return valueOne + ((valueTwo - valueOne) * alpha)
	end

	local function LerpColor3(colorOne: Color3, colorTwo: Color3, alpha: number)
		return Color3.new(
			LerpNumber(colorOne.R, colorTwo.R, alpha),
			LerpNumber(colorOne.G, colorTwo.G, alpha),
			LerpNumber(colorOne.B, colorTwo.B, alpha)
		)
	end

	TweenColor3, StopColor3Tween = makePropertyTweener(function(gui, percent, startProperties, newProperties)
		for index, endValue in next, newProperties do
			local StartProperty = startProperties[index]
			gui[index] = LerpColor3(StartProperty, endValue, percent)
		end
	end)
end

qGUI.TweenColor3 = TweenColor3
qGUI.StopColor3Tween = StopColor3Tween

-- Makes a 'Textured' window...  9Scale thingy?
function qGUI.AddTexturedWindowTemplate(frame: Frame, radius: number, type: string)
	type = type or "Frame"

	local topLeft = Instance.new(type)
	topLeft.Archivable = false
	topLeft.BackgroundColor3 = frame.BackgroundColor3
	topLeft.BorderSizePixel = 0
	topLeft.Name = "TopLeft"
	topLeft.Position = UDim2.new(0, 0, 0, 0)
	topLeft.Size = UDim2.new(0, radius, 0, radius)
	topLeft.BackgroundTransparency = 1
	topLeft.ZIndex = frame.ZIndex
	topLeft.Parent = frame

	local bottomLeft = Instance.new(type)
	bottomLeft.Archivable = false
	bottomLeft.BackgroundColor3 = frame.BackgroundColor3
	bottomLeft.BorderSizePixel = 0
	bottomLeft.Name = "BottomLeft"
	bottomLeft.Position = UDim2.new(0, 0, 1, -radius)
	bottomLeft.Size = UDim2.new(0, radius, 0, radius)
	bottomLeft.BackgroundTransparency = 1
	bottomLeft.ZIndex = frame.ZIndex
	bottomLeft.Parent = frame

	local topRight = Instance.new(type)
	topRight.Archivable = false
	topRight.BackgroundColor3 = frame.BackgroundColor3
	topRight.BorderSizePixel = 0
	topRight.Name = "TopRight"
	topRight.Position = UDim2.new(1, -radius, 0, 0)
	topRight.Size = UDim2.new(0, radius, 0, radius)
	topRight.BackgroundTransparency = 1
	topRight.ZIndex = frame.ZIndex
	topRight.Parent = frame

	local bottomRight = Instance.new(type)
	bottomRight.Archivable = false
	bottomRight.BackgroundColor3 = frame.BackgroundColor3
	bottomRight.BorderSizePixel = 0
	bottomRight.Name = "BottomRight"
	bottomRight.Position = UDim2.new(1, -radius, 1, -radius)
	bottomRight.Size = UDim2.new(0, radius, 0, radius)
	bottomRight.BackgroundTransparency = 1
	bottomRight.ZIndex = frame.ZIndex
	bottomRight.Parent = frame

	local middle = Instance.new(type)
	middle.Archivable = false
	middle.BackgroundColor3 = frame.BackgroundColor3
	middle.BorderSizePixel = 0
	middle.Name = "Middle"
	middle.Position = UDim2.new(0, radius, 0, 0)
	middle.Size = UDim2.new(1, -radius * 2, 1, 0)
	middle.BackgroundTransparency = 1
	middle.ZIndex = frame.ZIndex
	middle.Parent = frame

	local middleLeft = Instance.new(type)
	middleLeft.Archivable = false
	middleLeft.BackgroundColor3 = frame.BackgroundColor3
	middleLeft.BorderSizePixel = 0
	middleLeft.Name = "MiddleLeft"
	middleLeft.Position = UDim2.new(0, 0, 0, radius)
	middleLeft.Size = UDim2.new(0, radius, 1, -radius * 2)
	middleLeft.BackgroundTransparency = 1
	middleLeft.ZIndex = frame.ZIndex
	middleLeft.Parent = frame

	local middleRight = Instance.new(type)
	middleRight.Archivable = false
	middleRight.BackgroundColor3 = frame.BackgroundColor3
	middleRight.BorderSizePixel = 0
	middleRight.Name = "MiddleRight"
	middleRight.Position = UDim2.new(1, -radius, 0, radius)
	middleRight.Size = UDim2.new(0, radius, 1, -radius * 2)
	middleRight.BackgroundTransparency = 1
	middleRight.ZIndex = frame.ZIndex
	middleRight.Parent = frame

	return topLeft, topRight, bottomLeft, bottomRight, middle, middleLeft, middleRight
end

--[=[
	Makes a NinePatch in the frame, with the image.

	@param frame Frame -- The frame to texturize
	@param radius -- the radius you want the image to be at
	@param type -- The type (Class) that the frame should be, either an ImageLabel or an ImageButton
	@param image -- The URL of the image in question
	@param imageSize -- The size of the image overall, suggested to be 99/divisible by 3. Vector2 value.
	@param properties any
]=]
function qGUI.AddNinePatch(
	frame: Frame,
	image: string,
	imageSize: Vector2,
	radius: number,
	type: "ImageLabel" | "ImageButton",
	properties
)
	properties = properties or {}
	type = type or "ImageLabel"
	local topLeft, topRight, bottomLeft, bottomRight, middle, middleLeft, middleRight =
		qGUI.AddTexturedWindowTemplate(frame, radius, type)

	middle.Size = UDim2.new(1, -radius * 2, 1, -radius * 2) -- Fix middle...
	middle.Position = UDim2.new(0, radius, 0, radius)

	local middleTop = Instance.new(type)
	middleTop.Archivable = false
	middleTop.BackgroundColor3 = frame.BackgroundColor3
	middleTop.BorderSizePixel = 0
	middleTop.Name = "MiddleTop"
	middleTop.Position = UDim2.new(0, radius, 0, 0)
	middleTop.Size = UDim2.new(1, -radius * 2, 0, radius)
	middleTop.BackgroundTransparency = 1
	middleTop.ZIndex = frame.ZIndex
	middleTop.Parent = frame

	local middleBottom = Instance.new(type)
	middleBottom.Archivable = false
	middleBottom.BackgroundColor3 = frame.BackgroundColor3
	middleBottom.BorderSizePixel = 0
	middleBottom.Name = "MiddleBottom"
	middleBottom.Position = UDim2.new(0, radius, 1, -radius)
	middleBottom.Size = UDim2.new(1, -radius * 2, 0, radius)
	middleBottom.BackgroundTransparency = 1
	middleBottom.ZIndex = frame.ZIndex
	middleBottom.Parent = frame

	for _, item in pairs({
		topLeft,
		topRight,
		bottomLeft,
		bottomRight,
		middle,
		middleLeft,
		middleRight,
		middleTop,
		middleBottom,
	}) do
		for Property, Value in properties do
			item[Property] = Value
		end
		item.Image = image
		item.ImageRectSize = Vector2.new(imageSize.X / 3, imageSize.Y / 3)
	end

	topRight.ImageRectOffset = Vector2.new(imageSize.X * (2 / 3), 0)
	middleRight.ImageRectOffset = Vector2.new(imageSize.X * (2 / 3), imageSize.Y / 3)
	bottomRight.ImageRectOffset = Vector2.new(imageSize.X * (2 / 3), imageSize.Y * (2 / 3))

	--TopLeft.ImageRectOffset = Vector2.new(0, 0)
	middleLeft.ImageRectOffset = Vector2.new(0, imageSize.Y / 3)
	bottomLeft.ImageRectOffset = Vector2.new(0, imageSize.Y * (2 / 3))

	middle.ImageRectOffset = Vector2.new(imageSize.X / 3, imageSize.Y / 3)
	middleTop.ImageRectOffset = Vector2.new(imageSize.Y / 3, 0)
	middleBottom.ImageRectOffset = Vector2.new(imageSize.Y / 3, imageSize.Y * (2 / 3))

	return topLeft, topRight, bottomLeft, bottomRight, middle, middleLeft, middleRight, middleTop, middleBottom
end

function qGUI.BackWithRoundedRectangle(Frame: Frame, Radius: number, Color: Color3?)
	Color = Color or Color3.new(1, 1, 1)

	return qGUI.AddNinePatch(Frame, "rbxassetid://176688412", Vector2.new(150, 150), Radius, "ImageLabel", {
		ImageColor3 = Color,
	})
end

return qGUI