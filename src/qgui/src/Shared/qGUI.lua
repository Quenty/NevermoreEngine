--[=[
	A group of utility functions to be used to help create visual effectcs with ROBLOX GUIs

	@deprecated 2.3.1
	@class qGui
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
	return function(Gui, NewProperties, Duration)

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
function qGUI.AddTexturedWindowTemplate(Frame: Frame, Radius: number, Type: string)
	Type = Type or "Frame"

	local TopLeft = Instance.new(Type)
	TopLeft.Archivable = false
	TopLeft.BackgroundColor3 = Frame.BackgroundColor3
	TopLeft.BorderSizePixel = 0
	TopLeft.Name = "TopLeft"
	TopLeft.Position = UDim2.new(0, 0, 0, 0)
	TopLeft.Size = UDim2.new(0, Radius, 0, Radius)
	TopLeft.BackgroundTransparency = 1
	TopLeft.ZIndex = Frame.ZIndex
	TopLeft.Parent = Frame

	local BottomLeft = Instance.new(Type)
	BottomLeft.Archivable = false
	BottomLeft.BackgroundColor3 = Frame.BackgroundColor3
	BottomLeft.BorderSizePixel = 0
	BottomLeft.Name = "BottomLeft"
	BottomLeft.Position = UDim2.new(0, 0, 1, -Radius)
	BottomLeft.Size = UDim2.new(0, Radius, 0, Radius)
	BottomLeft.BackgroundTransparency = 1
	BottomLeft.ZIndex = Frame.ZIndex
	BottomLeft.Parent = Frame

	local TopRight = Instance.new(Type)
	TopRight.Archivable = false
	TopRight.BackgroundColor3 = Frame.BackgroundColor3
	TopRight.BorderSizePixel = 0
	TopRight.Name = "TopRight"
	TopRight.Position = UDim2.new(1, -Radius, 0, 0)
	TopRight.Size = UDim2.new(0, Radius, 0, Radius)
	TopRight.BackgroundTransparency = 1
	TopRight.ZIndex = Frame.ZIndex
	TopRight.Parent = Frame

	local BottomRight = Instance.new(Type)
	BottomRight.Archivable = false
	BottomRight.BackgroundColor3 = Frame.BackgroundColor3
	BottomRight.BorderSizePixel = 0
	BottomRight.Name = "BottomRight"
	BottomRight.Position = UDim2.new(1, -Radius, 1, -Radius)
	BottomRight.Size = UDim2.new(0, Radius, 0, Radius)
	BottomRight.BackgroundTransparency = 1
	BottomRight.ZIndex = Frame.ZIndex
	BottomRight.Parent = Frame

	local Middle = Instance.new(Type)
	Middle.Archivable = false
	Middle.BackgroundColor3 = Frame.BackgroundColor3
	Middle.BorderSizePixel = 0
	Middle.Name = "Middle"
	Middle.Position = UDim2.new(0, Radius, 0, 0)
	Middle.Size = UDim2.new(1, -Radius * 2, 1, 0)
	Middle.BackgroundTransparency = 1
	Middle.ZIndex = Frame.ZIndex
	Middle.Parent = Frame

	local MiddleLeft = Instance.new(Type)
	MiddleLeft.Archivable = false
	MiddleLeft.BackgroundColor3 = Frame.BackgroundColor3
	MiddleLeft.BorderSizePixel = 0
	MiddleLeft.Name = "MiddleLeft"
	MiddleLeft.Position = UDim2.new(0, 0, 0, Radius)
	MiddleLeft.Size = UDim2.new(0, Radius, 1, -Radius * 2)
	MiddleLeft.BackgroundTransparency = 1
	MiddleLeft.ZIndex = Frame.ZIndex
	MiddleLeft.Parent = Frame

	local MiddleRight = Instance.new(Type)
	MiddleRight.Archivable = false
	MiddleRight.BackgroundColor3 = Frame.BackgroundColor3
	MiddleRight.BorderSizePixel = 0
	MiddleRight.Name = "MiddleRight"
	MiddleRight.Position = UDim2.new(1, -Radius, 0, Radius)
	MiddleRight.Size = UDim2.new(0, Radius, 1, -Radius * 2)
	MiddleRight.BackgroundTransparency = 1
	MiddleRight.ZIndex = Frame.ZIndex
	MiddleRight.Parent = Frame

	return TopLeft, TopRight, BottomLeft, BottomRight, Middle, MiddleLeft, MiddleRight
end

-- Makes a NinePatch in the frame, with the image.
-- @param Frame The frame to texturize
-- @param Radius the radius you want the image to be at
-- @param Type The type (Class) that the frame should be, either an ImageLabel or an ImageButton
-- @param Image The URL of the image in question
-- @param ImageSize The size of the image overall, suggested to be 99/divisible by 3. Vector2 value.
function qGUI.AddNinePatch(
	Frame: Frame,
	Image: string,
	ImageSize: Vector2,
	Radius: number,
	Type: "ImageLabel" | "ImageButton",
	Properties
)
	Properties = Properties or {}
	Type = Type or "ImageLabel"
	local TopLeft, TopRight, BottomLeft, BottomRight, Middle, MiddleLeft, MiddleRight =
		qGUI.AddTexturedWindowTemplate(Frame, Radius, Type)

	Middle.Size = UDim2.new(1, -Radius * 2, 1, -Radius * 2) -- Fix middle...
	Middle.Position = UDim2.new(0, Radius, 0, Radius)

	local middleTop = Instance.new(Type)
	middleTop.Archivable = false
	middleTop.BackgroundColor3 = Frame.BackgroundColor3
	middleTop.BorderSizePixel = 0
	middleTop.Name = "MiddleTop"
	middleTop.Position = UDim2.new(0, Radius, 0, 0)
	middleTop.Size = UDim2.new(1, -Radius * 2, 0, Radius)
	middleTop.BackgroundTransparency = 1
	middleTop.ZIndex = Frame.ZIndex
	middleTop.Parent = Frame

	local MiddleBottom = Instance.new(Type)
	MiddleBottom.Archivable = false
	MiddleBottom.BackgroundColor3 = Frame.BackgroundColor3
	MiddleBottom.BorderSizePixel = 0
	MiddleBottom.Name = "MiddleBottom"
	MiddleBottom.Position = UDim2.new(0, Radius, 1, -Radius)
	MiddleBottom.Size = UDim2.new(1, -Radius * 2, 0, Radius)
	MiddleBottom.BackgroundTransparency = 1
	MiddleBottom.ZIndex = Frame.ZIndex
	MiddleBottom.Parent = Frame

	for _, Item in pairs({
		TopLeft,
		TopRight,
		BottomLeft,
		BottomRight,
		Middle,
		MiddleLeft,
		MiddleRight,
		middleTop,
		MiddleBottom,
	}) do
		for Property, Value in Properties do
			Item[Property] = Value
		end
		Item.Image = Image
		Item.ImageRectSize = Vector2.new(ImageSize.X / 3, ImageSize.Y / 3)
	end

	TopRight.ImageRectOffset = Vector2.new(ImageSize.X * (2 / 3), 0)
	MiddleRight.ImageRectOffset = Vector2.new(ImageSize.X * (2 / 3), ImageSize.Y / 3)
	BottomRight.ImageRectOffset = Vector2.new(ImageSize.X * (2 / 3), ImageSize.Y * (2 / 3))

	--TopLeft.ImageRectOffset = Vector2.new(0, 0)
	MiddleLeft.ImageRectOffset = Vector2.new(0, ImageSize.Y / 3)
	BottomLeft.ImageRectOffset = Vector2.new(0, ImageSize.Y * (2 / 3))

	Middle.ImageRectOffset = Vector2.new(ImageSize.X / 3, ImageSize.Y / 3)
	middleTop.ImageRectOffset = Vector2.new(ImageSize.Y / 3, 0)
	MiddleBottom.ImageRectOffset = Vector2.new(ImageSize.Y / 3, ImageSize.Y * (2 / 3))

	return TopLeft, TopRight, BottomLeft, BottomRight, Middle, MiddleLeft, MiddleRight, middleTop, MiddleBottom
end

function qGUI.BackWithRoundedRectangle(Frame: Frame, Radius: number, Color: Color3?)
	Color = Color or Color3.new(1, 1, 1)

	return qGUI.AddNinePatch(Frame, "rbxassetid://176688412", Vector2.new(150, 150), Radius, "ImageLabel", {
		ImageColor3 = Color,
	})
end

return qGUI