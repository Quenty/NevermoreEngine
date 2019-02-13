--- A group of utility functions to be used to help create visual effectcs with ROBLOX GUIs
-- @classmod qGui

local RunService = game:GetService("RunService")

local lib = {}

function lib.PointInBounds(Frame, X, Y)
	local TopBound = Frame.AbsolutePosition.Y
	local BottomBound = Frame.AbsolutePosition.Y + Frame.AbsoluteSize.Y
	local LeftBound = Frame.AbsolutePosition.X
	local RightBound = Frame.AbsolutePosition.X + Frame.AbsoluteSize.X

	if Y > TopBound and Y < BottomBound and X > LeftBound and X < RightBound then
		return true
	else
		return false
	end
end

function lib.MouseOver(Mouse, Frame)
	return lib.PointInBounds(Frame, Mouse.X, Mouse.Y)
end

-- @param UpdateFunction()
-- @return ShouldStop, if true, will stop updating
-- @return StartUpdate()
local function CreateYieldedUpdate(UpdateFunction)
	local AnimationId = 0
	local LastUpdatePoint = -1 -- If it's -1, no active thread.

	--- Increments the AnimationId and returns a new UpdateFunction
	-- to be bound into RenderStep
	local function GetNewUpdateFunction(RenderStepKey)

		local LocalAnimationId = AnimationId + 1
		AnimationId = LocalAnimationId

		-- Note that we're now updating.
		LastUpdatePoint = tick()

		--- Intended to be called each RenderStep. Will unbind itself if the UpdateFunction fails
		-- or a new update function is generated
		return function()
			LastUpdatePoint = tick()

			if UpdateFunction() or (AnimationId ~= LocalAnimationId) then
				RunService:UnbindFromRenderStep(RenderStepKey)

				if AnimationId == LocalAnimationId then
					LastUpdatePoint = -1
				end
			end
		end
	end

	--- Calculates the time since the last update function was called
	-- Used to determine if a new update function should be generated, since clients tend to
	-- kill threads when local scripts are GCed
	local function TimeSinceUpdate()

		return tick() - LastUpdatePoint
	end

	local function ShouldStartUpdate()
		return LastUpdatePoint == -1 -- In this case, we have no active threads
			or TimeSinceUpdate() > 0.1 -- In this case, our presumed active thread is dead.
	end

	--- Starts an update thread, potentialy removing the old one.
	local function StartNewThread()
		local RenderStepKey = "TweenTransparencyOnGuis" .. tostring(UpdateFunction) .. tick()
		RunService:BindToRenderStep(RenderStepKey, 2000, GetNewUpdateFunction(RenderStepKey))
	end

	--- Starts the tween
	return function()
		if ShouldStartUpdate() then
			StartNewThread()
		end
	end
end

--- Creates a tweener that only runs when it's updating with a set properties system.
-- @param function `SetProperties`
	-- SetProperties(Gui, Percent, StartProperties, NewProperties)
		-- @param Gui The Gui to set properties on
		-- @param Percent Number [0, 1] of properties to set
		-- @param StartProperties The properties we started with
		-- @param NewProperties The properties we ended with
-- @return
local function MakePropertyTweener(SetProperties)
	local GuiMap = {} -- [Gui] = TweenData

	local function GetTweenData(Gui, NewProperties, Duration)
		-- Returns new tween data for the GUI in question

		local StartProperties = {}
		local EndProperties = {}

		-- Copy data into the table
		for Index, Value in pairs(NewProperties) do
			if Gui[Index] ~= Value then
				StartProperties[Index] = Gui[Index]
				EndProperties[Index] = Value
			end
		end

		return {
			StartTime       = tick();
			Duration        = Duration;
			StartProperties = StartProperties;
			NewProperties   = EndProperties;
		}
	end

	local StartRenderStepUpdater = CreateYieldedUpdate(function()
		-- Update function that will be called each second

		local tick = tick()
		local ShouldStop = true

		for Gui, TweenState in next, GuiMap do
			if Gui:IsDescendantOf(game) then
				local TimeElapsed = tick - TweenState.StartTime

				if TimeElapsed > TweenState.Duration then -- Then we end it.
					SetProperties(Gui, 1, TweenState.StartProperties, TweenState.NewProperties)
					GuiMap[Gui] = nil
				else
					SetProperties(Gui, TimeElapsed/TweenState.Duration, TweenState.StartProperties, TweenState.NewProperties)
					ShouldStop = false
				end
			else
				GuiMap[Gui] = nil
			end
		end

		return ShouldStop
	end)

	--- A tweening function to begin tweening on a Gui element
	-- @param Gui The GUI to tween the Transparency's upon
	-- @param NewProperties The properties to be changed. It will take the current
	--                      properties and tween to the new ones. This table should be
	--                      setup so {Index = NewValue} that is, for example,
	--                      {TextTransparency = 1}.
	-- @param Duration The amount of time to spend transitioning.
	return function(Gui, NewProperties, Duration)

		if Duration <= 0 then
			SetProperties(Gui, 1, NewProperties, NewProperties)
		else
			GuiMap[Gui] = GetTweenData(Gui, NewProperties, Duration)
			StartRenderStepUpdater()
		end

	-- A tweening function to manually terminate tweening on a Gui element
	-- @param Gui The GUI to stop tweening
	end, function(Gui)
		GuiMap[Gui] = nil
	end
end

-- TweenTransparency(Gui, NewProperties, Time)
--- Tween's the Transparency values in a GUI,
-- @param Gui The GUI to tween the Transparency's upon
-- @param NewProperties The properties to be changed. It will take the current
--                      properties and tween to the new ones. This table should be
--                      setup so {Index = NewValue} that is, for example,
--                      {TextTransparency = 1}.
-- @param Time The amount of time to spend transitioning.
local TweenTransparency, StopTransparencyTween = MakePropertyTweener(function(Gui, Percent, StartProperties, NewProperties)
	for Index, EndValue in next, NewProperties do
		local StartProperty = StartProperties[Index]
		Gui[Index] = StartProperty + (EndValue - StartProperty) * Percent
	end
end)

lib.TweenTransparency = TweenTransparency
lib.StopTransparencyTween = StopTransparencyTween


--- TweenColor3(Gui, NewProperties, Time)
--- Tween's the Color3 values in a GUI,
-- @param Gui The GUI to tween the Color3's upon
-- @param NewProperties The properties to be changed. It will take the current
--                      properties and tween to the new ones. This table should be
--                      setup so {Index = NewValue} that is, for example,
--                      {BackgroundColor3 = Color3.new(1, 1, 1)}.
-- @param Duration The amount of time to spend transitioning.
local TweenColor3, StopColor3Tween do
	local function LerpNumber(ValueOne, ValueTwo, Alpha)
		return ValueOne + ((ValueTwo - ValueOne) * Alpha)
	end

	local function LerpColor3(ColorOne, ColorTwo, Alpha)
		return Color3.new(LerpNumber(ColorOne.r, ColorTwo.r, Alpha), LerpNumber(ColorOne.g, ColorTwo.g, Alpha), LerpNumber(ColorOne.b, ColorTwo.b, Alpha))
	end

	TweenColor3, StopColor3Tween = MakePropertyTweener(function(Gui, Percent, StartProperties, NewProperties)
		for Index, EndValue in next, NewProperties do
			local StartProperty = StartProperties[Index]
			Gui[Index] = LerpColor3(StartProperty, EndValue, Percent)
		end
	end)
end

lib.TweenColor3 = TweenColor3
lib.StopColor3Tween = StopColor3Tween

--- Makes a 'Textured' window...  9Scale thingy?
local function AddTexturedWindowTemplate(Frame, Radius, Type)
	Type = Type or 'Frame'

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
	Middle.Size = UDim2.new(1, -Radius*2, 1, 0)
	Middle.BackgroundTransparency = 1
	Middle.ZIndex = Frame.ZIndex
	Middle.Parent = Frame

	local MiddleLeft = Instance.new(Type)
	MiddleLeft.Archivable = false
	MiddleLeft.BackgroundColor3 = Frame.BackgroundColor3
	MiddleLeft.BorderSizePixel = 0
	MiddleLeft.Name = "MiddleLeft"
	MiddleLeft.Position = UDim2.new(0, 0, 0, Radius)
	MiddleLeft.Size = UDim2.new(0, Radius, 1, -Radius*2)
	MiddleLeft.BackgroundTransparency = 1
	MiddleLeft.ZIndex = Frame.ZIndex
	MiddleLeft.Parent = Frame

	local MiddleRight = Instance.new(Type)
	MiddleRight.Archivable = false
	MiddleRight.BackgroundColor3 = Frame.BackgroundColor3
	MiddleRight.BorderSizePixel = 0
	MiddleRight.Name = "MiddleRight"
	MiddleRight.Position = UDim2.new(1, -Radius, 0, Radius)
	MiddleRight.Size = UDim2.new(0, Radius, 1, -Radius*2)
	MiddleRight.BackgroundTransparency = 1
	MiddleRight.ZIndex = Frame.ZIndex
	MiddleRight.Parent = Frame

	return TopLeft, TopRight, BottomLeft, BottomRight, Middle, MiddleLeft, MiddleRight
end
lib.AddTexturedWindowTemplate = AddTexturedWindowTemplate

--- Makes a NinePatch in the frame, with the image.
-- @param Frame The frame to texturize
-- @param Radius the radius you want the image to be at
-- @param Type The type (Class) that the frame should be, either an ImageLabel or an ImageButton
-- @param Image The URL of the image in question
-- @param ImageSize The size of the image overall, suggested to be 99/divisible by 3. Vector2 value.
local function AddNinePatch(Frame, Image, ImageSize, Radius, Type, Properties)
	Properties = Properties or {}
	Type = Type or "ImageLabel"
	local TopLeft, TopRight, BottomLeft, BottomRight, Middle, MiddleLeft, MiddleRight = AddTexturedWindowTemplate(Frame, Radius, Type)

	Middle.Size = UDim2.new(1, -Radius*2, 1, -Radius*2) -- Fix middle...
	Middle.Position = UDim2.new(0, Radius, 0, Radius)

	local MiddleTop = Instance.new(Type)
	MiddleTop.Archivable = false
	MiddleTop.BackgroundColor3 = Frame.BackgroundColor3
	MiddleTop.BorderSizePixel = 0
	MiddleTop.Name = "MiddleTop"
	MiddleTop.Position = UDim2.new(0, Radius, 0, 0)
	MiddleTop.Size = UDim2.new(1, -Radius*2, 0, Radius)
	MiddleTop.BackgroundTransparency = 1
	MiddleTop.ZIndex = Frame.ZIndex
	MiddleTop.Parent = Frame

	local MiddleBottom = Instance.new(Type)
	MiddleBottom.Archivable = false
	MiddleBottom.BackgroundColor3 = Frame.BackgroundColor3
	MiddleBottom.BorderSizePixel = 0
	MiddleBottom.Name = "MiddleBottom"
	MiddleBottom.Position = UDim2.new(0, Radius, 1, -Radius)
	MiddleBottom.Size = UDim2.new(1, -Radius*2, 0, Radius)
	MiddleBottom.BackgroundTransparency = 1
	MiddleBottom.ZIndex = Frame.ZIndex
	MiddleBottom.Parent = Frame

	for _, Item in pairs({TopLeft, TopRight, BottomLeft, BottomRight, Middle, MiddleLeft, MiddleRight, MiddleTop, MiddleBottom}) do
		for Property, Value in pairs(Properties) do
			Item[Property] = Value
		end
		Item.Image = Image
		Item.ImageRectSize = Vector2.new(ImageSize.X/3, ImageSize.Y/3)
	end

	TopRight.ImageRectOffset = Vector2.new(ImageSize.X * (2/3), 0)
	MiddleRight.ImageRectOffset = Vector2.new(ImageSize.X * (2/3), ImageSize.Y/3)
	BottomRight.ImageRectOffset = Vector2.new(ImageSize.X * (2/3), ImageSize.Y * (2/3))

	--TopLeft.ImageRectOffset = Vector2.new(0, 0)
	MiddleLeft.ImageRectOffset = Vector2.new(0, ImageSize.Y/3)
	BottomLeft.ImageRectOffset = Vector2.new(0, ImageSize.Y * (2/3))

	Middle.ImageRectOffset = Vector2.new(ImageSize.X/3, ImageSize.Y/3)
	MiddleTop.ImageRectOffset = Vector2.new(ImageSize.Y/3, 0)
	MiddleBottom.ImageRectOffset = Vector2.new(ImageSize.Y/3, ImageSize.Y * (2/3))

	return TopLeft, TopRight, BottomLeft, BottomRight, Middle, MiddleLeft, MiddleRight, MiddleTop, MiddleBottom
end
lib.AddNinePatch = AddNinePatch

local function BackWithRoundedRectangle(Frame, Radius, Color)
	Color = Color or Color3.new(1, 1, 1);

	return AddNinePatch(Frame, "rbxassetid://176688412", Vector2.new(150, 150), Radius, "ImageLabel", {
		ImageColor3 = Color;
	})
end
lib.BackWithRoundedRectangle = BackWithRoundedRectangle

return lib