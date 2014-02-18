local Players            = game:GetService("Players")
local StarterPack        = game:GetService("StarterPack")
local StarterGui         = game:GetService("StarterGui")
local Lighting           = game:GetService("Lighting")
local Debris             = game:GetService("Debris")
local Teams              = game:GetService("Teams")
local BadgeService       = game:GetService("BadgeService")
local InsertService      = game:GetService("InsertService")
local HttpService        = game:GetService("HttpService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService   = game:GetService("UserInputService")
local Terrain            = Workspace.Terrain

local NevermoreEngine    = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary  = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local qMath             = LoadCustomLibrary("qMath")
local qCFrame           = LoadCustomLibrary("qCFrame")
local Table             = LoadCustomLibrary("Table")
local qColor3           = LoadCustomLibrary("qColor3")

qSystems:import(getfenv(0));

local lib = {}

local DEFAULTS = {}

local WEAK_MODE = {
	K = {__mode="k"};
	V = {__mode="v"};
	KV = {__mode="kv"};
}

local COLORS = {
	

}

-- qGUI.lua
-- @author Quenty
-- A group of utility functions to be used by ROBLOX GUIs

--[[

Change Log
February 15th, 2014
- Updated TweenTransparency method to use single thread update model for efficiency.
- Updated TweenColor3 method to use a single thread update model for efficiency.

--]]


local function GetScreen(object)
	-- Given a GUI object, returns it's screenGui. 

	--[[
	GetScreen ( Instance `object` )
		returns ScreenGui `screen`

	Gets the nearest ascending ScreenGui of `object`.
	Returns `object` if it is a ScreenGui.
	Returns nil if `object` isn't the descendant of a ScreenGui.

	Arguments:
		`object`
			The instance to get the ascending ScreenGui from.

	Returns:
		`screen`
			The ascending screen.
			Will be nil if `object` isn't the descendant of a ScreenGui.
	--]]

	local screen = object
	while not screen:IsA("ScreenGui") do
		screen = screen.Parent
		if screen == nil then return nil end
	end
	return screen
end
lib.GetScreen = GetScreen
lib.getScreen = GetScreen
lib.get_screen = GetScreens

local function NewColor3(red, green, blue)
	-- Given a red, green, and blue, it'll return a formatted Color3 object. 
	return Color3.new(red/255, green/255, blue/255)
end
lib.NewColor3 = NewColor3
lib.newColor3 = NewColor3
lib.new_color3 = NewColor3

lib.MakeColor3 = NewColor3
lib.makeColor3 = NewColor3

local function GetCenteringPosition(Object)
	-- Return's the center of
	return UDim2.new(0.5, -Object.AbsoluteSize.X/2, 0.5, -Object.AbsoluteSize.Y/2)
end
lib.GetCenteringPosition = GetCenteringPosition
lib.getCenteringPosition = GetCenteringPosition
lib.get_centering_position = GetCenteringPosition

local function GetHalfSize(Object)
	-- Return's half the size of an object. 

	local ObjectSize = Object.Size
	return UDim2.new(ObjectSize.X.Scale / 2, ObjectSize.X.Offset /2, ObjectSize.Y.Scale / 2, ObjectSize.Y.Offset / 2)
end
lib.GetHalfSize = GetHalfSize
lib.getHalfSize = GetHalfSize
lib.get_half_size = GetHalfSize

local function Center(Object)
	-- Centers an object (Sized with offset) into the middle of the screen.

	Object.Position = GetCenteringPosition(Object)
end
lib.Center = Center
lib.center = center

local function MouseOver(Mouse, Frame)
	local TopBound 		= Frame.AbsolutePosition.Y
	local BottomBound 	= Frame.AbsolutePosition.Y + Frame.AbsoluteSize.Y
	local LeftBound		= Frame.AbsolutePosition.X
	local RightBound		= Frame.AbsolutePosition.X + Frame.AbsoluteSize.X
	if Mouse.Y > TopBound and Mouse.Y < BottomBound and Mouse.X > LeftBound and Mouse.X < RightBound then
		return true
	else
		return false
	end
end
lib.MouseOver = MouseOver
lib.mouseOver = MouseOver
lib.mouse_over = MouseOver

local function SubtractColor3(a, b)
	local R = a.r + b.r
	local G = a.g + b.g
	local B = a.b + b.b
	return Color3.new(R, G, B)
end
lib.SubtractColor3 = SubtractColor3
lib.subtractColor3 = SubtractColor3
lib.subtract_color3 = SubtractColor3

local function MultiplyColor3(Num, Color)
	-- Multiplies a Color3 by Num

	local R = Color.r * Num
	local G = Color.g * Num
	local B = Color.b * Num
	return Color3.new(R, G, B)
end
lib.MultiplyColor3 = MultiplyColor3
lib.multiplyColor3 = MultiplyColor3
lib.multiply_color3 = MultiplyColor3

local function InverseColor3(Color)
	-- Inverses a Color3...

	return Color3.new(1 - Color.r, 1 - Color.g, 1 - Color.b)
end
lib.InverseColor3 = InverseColor3
lib.inverseColor3 = InverseColor3
lib.inverse_color3 = InverseColor3

local function IsPhone(ScreenGui)
	-- Return's if ROBLOX is being played on a phone or not.

	if ScreenGui.AbsoluteSize.Y < 600 and UserInputService.TouchEnabled then 
		return true
	end 
	return false 
end
lib.isPhone = IsPhone
lib.IsPhone = IsPhone
lib.is_phone = IsPhone

local function TouchOnly()
	-- Return's if it's TouchOnly

	return not UserInputService.MouseEnabled 
end
lib.TouchOnly = TouchOnly
lib.touchOnly = TouchOnly
lib.touch_only = TouchOnly

local function UDim2OffsetFromVector2(Vector2ConvertFrom)
	-- Return's a UDim2 generated from the Vector2ConvertFrom

	return UDim2.new(0, Vector2ConvertFrom.X, 0, Vector2ConvertFrom.Y)
end
lib.UDim2OffsetFromVector2 = UDim2OffsetFromVector2
lib.uDim2OffsetFromVector2 = UDim2OffsetFromVector2
lib.udim2_offset_from_vector2 = UDim2OffsetFromVector2

do
	local PointToObjectSpace = CFrame.new().pointToObjectSpace
	local atan2              = math.atan2
	local tan                = math.tan
	local Vector2New         = Vector2.new
	local abs                = math.abs
	local max                = math.max
	local min                = math.min
	local pi                 = math.pi

	local PiOver360 = pi / 360
	-- local Sign = Sign

	local function WorldToScreen(Position, Mouse, Camera)
		-- Translates a position in ROBLOX space to ScreenSpace.  
		-- Math credit to xXxMoNkEyMaNxXx
		-- Returns if it's on the screen, then the ScreenPosition, and then the angle at which the object is (if it's off the screen?) Not sure entirely.
		
		local RealPosition = PointToObjectSpace(Camera.CoordinateFrame, Position)
		local RealPositionX = RealPosition.x
		local RealPositionY = RealPosition.y
		local RealPositionZ = RealPosition.z

		local Angle = atan2(RealPositionX, -RealPositionY) -- Rotate 90 degrees ccw so that angles start at "straight down"
		local Theta
		local ViewSize = Vector2New(Mouse.ViewSizeX, Mouse.ViewSizeY) / 2
		if RealPositionZ < 0 then -- Object is in front
			local ATY = tan(Camera.FieldOfView * PiOver360)
			local AT1 = Vector2New(ATY * ViewSize.X / ViewSize.Y, ATY)
			local UPOS = Vector2New(-RealPositionX, RealPositionY) / RealPositionZ
			local SPOS = ViewSize + ViewSize * UPOS / AT1
			if SPOS.X >= 0 and SPOS.X <= Mouse.ViewSizeX and SPOS.Y >= 0 and SPOS.Y <= Mouse.ViewSizeY then
				return true, SPOS, Angle
			else
				Theta = true
			end
		else
			Theta = true
		end
		if Theta then
			return false, 
			ViewSize + Vector2New(Sign(RealPositionX) * abs(max(-ViewSize.x, min(ViewSize.x, ViewSize.y * RealPositionX/RealPositionY))), -Sign(RealPositionY) * abs(max(-ViewSize.y,min(ViewSize.y,ViewSize.x * RealPositionY/RealPositionX)))),
			Angle
		end
	end
	lib.WorldToScreen = WorldToScreen
	lib.worldToScreen = WorldToScreen
	lib.world_to_screen = WorldToScreen
end

local function MultiplyUDim2Offset(Original, Factor)
	return UDim2.new(Original.X.Scale, Original.X.Offset * Factor, Original.Y.Scale, Original.Y.OFfset * Factor)
end
lib.MultiplyUDim2Offset = MultiplyUDim2Offset
lib.multiplyUDim2Offset = MultiplyUDim2Offset

local function PickRandomColor3(List)
	return List[math.random(1, #List)]
end
lib.PickRandomColor3 = PickRandomColor3
lib.pickRandomColor3 = PickRandomColor3

local FrameImageIds = {}
local FrameOperationIds = {}
local FrameTweenOperatingStatus = {}

setmetatable(FrameImageIds, WEAK_MODE.K)
setmetatable(FrameOperationIds, WEAK_MODE.K)
setmetatable(FrameTweenOperatingStatus, WEAK_MODE.K)

local function SetImageId(Frame, ImageId, TotalVisibleCount)
	FrameImageIds[Frame] = {
		TotalVisibleCount = TotalVisibleCount; -- How many frames are required to make it "Entirely" visible.
		ImageId = ImageId;
		ActiveImages = {};
	};
	return FrameImageIds[Frame]
end
lib.SetImageId = SetImageId
lib.setImageId = SetImageId

local function TweenImages(Gui, Time, Target, Override)
	-- So we can layer image labels and make it look nice. 
	-- Target is a number between 0 and the FrameId.TotalVisibleCount...
	-- If target is a boolean then it'll be set to the TotalVisibleCount if it's true, or 0 if it's false.
	if not FrameImageIds[Gui] then
		error("[qGUI] - FrameImageIds[" .. tostring(Gui) .. "] has not been set, can not tween")
	end

	if type(Target) == "boolean" then
		if Target then
			Target = FrameImageIds[Gui].TotalVisibleCount 
		else
			Target = 0
		end
	else
		Target = qMath.ClampNumber(Target, 0, FrameImageIds[Gui].TotalVisibleCount)
	end

	local CanExecute = false
	FrameOperationIds[Gui] = FrameOperationIds[Gui] or 0

	if FrameTweenOperatingStatus[Gui] and Override then
		FrameOperationIds[Gui] = FrameOperationIds[Gui] + 1
	elseif FrameTweenOperatingStatus[Gui] then
		return false
	end

	local LocalTweenId = FrameOperationIds[Gui]
	FrameTweenOperatingStatus[Gui] = true

	Spawn(function()
		local FrameId = FrameImageIds[Gui]
		local StartTime = time()
		local CurrentTime = time()
		local StartCount = #FrameId.ActiveImages

		local function PropogangateFrames(Percent)
			local CurrentTarget = qMath.ClampNumber(qMath.RoundNumber(StartCount + (Target - StartCount) * Percent, 1), 0, FrameImageIds[Gui].TotalVisibleCount)
			for Index=1, math.max(CurrentTarget, #FrameId.ActiveImages) do
				if Index <= CurrentTarget then
					if not FrameId.ActiveImages[Index] then
						FrameId.ActiveImages[Index] = Make 'ImageLabel' {
							Name = "TweenId"..Index;
							Parent = Gui;
							BorderSizePixel = 0;
							BackgroundTransparency = 1;
							Archivable = false;
							Image = FrameId.ImageId;
							Size = UDim2.new(1, 0, 1, 0);
						};
					end
				else
					if FrameId.ActiveImages[Index] then -- Remove it, it's too high!
						FrameId.ActiveImages[Index]:Destroy()
						FrameId.ActiveImages[Index] = nil
					end
				end
			end
		end

		while LocalTweenId == FrameOperationIds[Gui] and StartTime + Time >= CurrentTime do
			local Percent = (CurrentTime - StartTime) / Time
			local SmoothedPercent = math.sin((Percent - 0.5) * math.pi)/2 + 0.5
			PropogangateFrames(SmoothedPercent)
			wait(0.05)
			CurrentTime = time()
		end

		if FrameOperationIds[Gui] ~= LocalTweenId then 
			return false
		end 


		FrameTweenOperatingStatus[Gui] = false
		PropogangateFrames(1)
	end)
end
lib.TweenImages = TweenImages
lib.tweenImages = TweenImages

do
	local ProcessList = {}
	-- setmetatable(ProcessList, WEAK_MODE.K)
	local ActivelyProcessing = false

	local function SetProperties(Gui, Percent, StartProperties, NewProperties)
		-- Maybe there's a better way to do this?

		for Index, EndValue in next, NewProperties do
			local StartProperty = StartProperties[Index]
			Gui[Index] = StartProperty + (EndValue - StartProperty) * Percent
		end
	end

	local function UpdateTweenModels()
		local CurrentTick = tick()
		ActivelyProcessing = false

		for Gui, TweenState in next, ProcessList do
			if Gui and Gui.Parent then
				ActivelyProcessing = true

				local TimeElapsed = (CurrentTick - TweenState.StartTime)
				local Duration    = TweenState.Duration

				if TimeElapsed > Duration then
					-- Then we end it.
					
					SetProperties(Gui, 1, TweenState.StartProperties, TweenState.NewProperties) 
					ProcessList[Gui] = nil
				else
					-- Otherwise do the animations.

					SetProperties(Gui, TimeElapsed/Duration, TweenState.StartProperties, TweenState.NewProperties)
				end
			else
				ProcessList[Gui] = nil
			end
		end
	end

	local function StartProcessUpdate()
		if not ActivelyProcessing then
			ActivelyProcessing = true
			Spawn(function()
				while ActivelyProcessing do
					UpdateTweenModels()
					RunService.RenderStepped:wait(0.05)
				end
			end)
		end
	end

	local function TweenTransparency(Gui, NewProperties, Duration, Override)
		-- Override tween system to tween the transparency of properties. Unfortunately, overriding is per a GUI as of now. 
		--- Tween's the Transparency values in a GUI,
		-- @param Gui The GUI to tween the Transparency's upon
		-- @param NewProperties The properties to be changed. It will take the current
		--                      properties and tween to the new ones. This table should be
		--                      setup so {Index = NewValue} that is, for example, 
		--                      {TextTransparency = 1}.
		-- @param Time The amount of time to spend transitioning.
		-- @param [Override] If true, it will override a previous animation, otherwise, it will not.

		if not ProcessList[Gui] or Override then
			-- Fill StartProperties
			local StartProperties = {}
			for Index, _ in pairs(NewProperties) do
				StartProperties[Index] = Gui[Index]	
			end

			-- And set NewState
			local NewState = {
				StartTime       = tick();
				Duration        = Duration;
				-- Gui          = Gui;
				StartProperties = StartProperties;
				NewProperties   = NewProperties;
			}

			ProcessList[Gui] = NewState
			StartProcessUpdate()
		end
	end
	lib.TweenTransparency = TweenTransparency
	lib.tweenTransparency = TweenTransparency

	local function StopTransparencyTween(Gui)
		-- Overrides all the current transparency animations in a GUI. Perhaps useful.
		-- @param Gui The GUI to stop the tween the Transparency's upon

		ProcessList[Gui] = nil
	end
	lib.StopTransparencyTween = StopTransparencyTween
	lib.stopTransparencyTween = StopTransparencyTween
end

do
	local ProcessList = {}
	-- setmetatable(ProcessList, WEAK_MODE.K)
	local ActivelyProcessing = false

	local LerpColor3 = qColor3.LerpColor3
	local function SetProperties(Gui, Percent, StartProperties, NewProperties)
		-- Maybe there's a better way to do this?

		for Index, EndValue in next, NewProperties do
			local StartProperty = StartProperties[Index]
			Gui[Index] = LerpColor3(StartProperty, EndValue, Percent)
		end
	end

	local function UpdateTweenModels()
		local CurrentTick = tick()
		ActivelyProcessing = false

		for Gui, TweenState in next, ProcessList do
			if Gui and Gui.Parent then
				ActivelyProcessing = true

				local TimeElapsed = (CurrentTick - TweenState.StartTime)
				local Duration    = TweenState.Duration

				if TimeElapsed > Duration then
					-- Then we end it.
					
					SetProperties(Gui, 1, TweenState.StartProperties, TweenState.NewProperties) 
					ProcessList[Gui] = nil
				else
					-- Otherwise do the animations.

					SetProperties(Gui, TimeElapsed/Duration, TweenState.StartProperties, TweenState.NewProperties)
				end
			else
				ProcessList[Gui] = nil
			end
		end
	end

	local function StartProcessUpdate()
		if not ActivelyProcessing then
			ActivelyProcessing = true
			Spawn(function()
				while ActivelyProcessing do
					UpdateTweenModels()
					RunService.RenderStepped:wait(0.05)
				end
			end)
		end
	end

	local function TweenColor3(Gui, NewProperties, Duration, Override)
		--- Tween's the Color3 values in a GUI,
		-- @param Gui The GUI to tween the Color3's upon
		-- @param NewProperties The properties to be changed. It will take the current
		--                      properties and tween to the new ones. This table should be
		--                      setup so {Index = NewValue} that is, for example, 
		--                      {BackgroundColor3 = Color3.new(1, 1, 1)}.
		-- @param Duration The amount of time to spend transitioning.
		-- @param [Override] If true, it will override a previous animation, otherwise, it will not.

		if not ProcessList[Gui] or Override then
			-- Fill StartProperties
			local StartProperties = {}
			for Index, _ in pairs(NewProperties) do
				StartProperties[Index] = Gui[Index]	
			end

			-- And set NewState
			local NewState = {
				StartTime       = tick();
				Duration        = Duration;
				-- Gui          = Gui;
				StartProperties = StartProperties;
				NewProperties   = NewProperties;
			}

			ProcessList[Gui] = NewState
			StartProcessUpdate()
		end
	end
	lib.TweenColor3 = TweenColor3
	lib.tweenColor3 = TweenColor3

	local function StopColor3Tween(Gui)
		-- Overrides all the current animations of Color3 in the GUI. 
		-- @param Gui The GUI to stop the tween animations on

		ProcessList[Gui] = nil
	end
	lib.StopColor3Tween = StopColor3Tween
	lib.stopColor3Tween = StopColor3Tween
end

local function GenerateMouseDrag()
	-- Generate's a dragger to catch the mouse...
	return Make 'ImageButton'{
		Active = false;
		Size = UDim2.new(1.5, 0, 1.5, 0);
		AutoButtonColor = false;
		BackgroundTransparency = 1;
		Name = "MouseDrag";
		Position = UDim2.new(-0.25, 0, -0.25, 0);
		ZIndex = 10;
	}
end
lib.GenerateMouseDrag = GenerateMouseDrag
lib.generateMouseDrag = GenerateMouseDrag

local function AddTexturedWindowTemplate(Frame, Radius, Type)
	-- Makes a 'Textured' window... 

	Type = Type or 'Frame';

	local TopLeft = Make(Type)({
		Archivable             = false;
		BackgroundColor3       = Frame.BackgroundColor3;
		BorderSizePixel        = 0;
		Name                   = "TopLeft";
		Parent                 = Frame;
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(0, Radius, 0, Radius);
		BackgroundTransparency = 1;
		ZIndex                 = Frame.ZIndex;
	});

	local TopRight = Make(Type)({
		Archivable             = false;
		BackgroundColor3       = Frame.BackgroundColor3;
		BorderSizePixel        = 0;
		Name                   = "TopRight";
		Parent                 = Frame;
		Position               = UDim2.new(0, 0, 1, -Radius);
		Size                   = UDim2.new(0, Radius, 0, Radius);
		BackgroundTransparency = 1;
		ZIndex                 = Frame.ZIndex;
	});

	local BottomLeft = Make(Type)({
		Archivable             = false;
		BackgroundColor3       = Frame.BackgroundColor3;
		BorderSizePixel        = 0;
		Name                   = "BottomLeft";
		Parent                 = Frame;
		Position               = UDim2.new(1, -Radius, 0, 0);
		Size                   = UDim2.new(0, Radius, 0, Radius);
		BackgroundTransparency = 1;
		ZIndex                 = Frame.ZIndex;
	});

	local BottomRight = Make(Type)({
		Archivable             = false;
		BackgroundColor3       = Frame.BackgroundColor3;
		BorderSizePixel        = 0;
		Name                   = "BottomRight";
		Parent                 = Frame;
		Position               = UDim2.new(1, -Radius, 1, -Radius);
		Size                   = UDim2.new(0, Radius, 0, Radius);
		BackgroundTransparency = 1;
		ZIndex                 = Frame.ZIndex;
	});

	local Middle = Make(Type)({
		Archivable             = false;
		BackgroundColor3       = Frame.BackgroundColor3;
		BorderSizePixel        = 0;
		Name                   = "Middle";
		Parent                 = Frame;
		Position               = UDim2.new(0, Radius, 0, 0);
		Size                   = UDim2.new(1, -Radius*2, 1, 0);
		BackgroundTransparency = 1;
		ZIndex                 = Frame.ZIndex;
	});

	local MiddleLeft = Make(Type)({
		Archivable             = false;
		BackgroundColor3       = Frame.BackgroundColor3;
		BorderSizePixel        = 0;
		Name                   = "MiddleLeft";
		Parent                 = Frame;
		Position               = UDim2.new(0, 0, 0, Radius);
		Size                   = UDim2.new(0, Radius, 1, -Radius*2);
		BackgroundTransparency = 1;
		ZIndex                 = Frame.ZIndex;
	});

	local MiddleRight = Make(Type)({
		Archivable             = false;
		BackgroundColor3       = Frame.BackgroundColor3;
		BorderSizePixel        = 0;
		Name                   = "MiddleRight";
		Parent                 = Frame;
		Position               = UDim2.new(1, -Radius, 0, Radius);
		Size                   = UDim2.new(0, Radius, 1, -Radius*2);
		BackgroundTransparency = 1;
		ZIndex                 = Frame.ZIndex;
	});

	return TopLeft, TopRight, BottomLeft, BottomRight, Middle, MiddleLeft, MiddleRight
end
lib.AddTexturedWindowTemplate = AddTexturedWindowTemplate
lib.addTexturedWindowTemplate = AddTexturedWindowTemplate

local function AddNinePatch(Frame, Image, ImageSize, Radius, Type)
	--- Makes a NinePatch in the frame, with the image. 
	-- @param Frame The frame to texturize
	-- @param Radius the radius you want the image to be at
	-- @param Type The type (Class) that the frame should be, either an ImageLabel or an ImageButton
	-- @param Image The URL of the image in question
	-- @param ImageSize The size of the image overall, suggested to be 99/divisible by 3. Vector2 value.

	Properties = Properties or {}
	Type = Type or "ImageLabel";
	local TopLeft, TopRight, BottomLeft, BottomRight, Middle, MiddleLeft, MiddleRight = AddTexturedWindowTemplate(Frame, Radius, Type)

	Middle.Size = UDim2.new(1, -Radius*2, 1, -Radius*2); -- Fix middle...
	Middle.Position = UDim2.new(0, Radius, 0, Radius);

	local MiddleTop = Make(Type)({
		Archivable             = false;
		BackgroundColor3       = Frame.BackgroundColor3;
		BorderSizePixel        = 0;
		Name                   = "MiddleTop";
		Parent                 = Frame;
		Position               = UDim2.new(0, Radius, 0, 0);
		Size                   = UDim2.new(1, -Radius*2, 0, Radius);
		BackgroundTransparency = 1;
		ZIndex                 = Frame.ZIndex;
	});

	local MiddleBottom = Make(Type)({
		Archivable             = false;
		BackgroundColor3       = Frame.BackgroundColor3;
		BorderSizePixel        = 0;
		Name                   = "MiddleBottom";
		Parent                 = Frame;
		Position               = UDim2.new(0, Radius, 1, -Radius);
		Size                   = UDim2.new(1, -Radius*2, 0, Radius);
		BackgroundTransparency = 1;
		ZIndex                 = Frame.ZIndex;
	});

	for _, Item in pairs({TopLeft, TopRight, BottomLeft, BottomRight, Middle, MiddleLeft, MiddleRight, MiddleTop, MiddleBottom}) do
		Modify(Item, Properties)
		Item.Image = Image;
		Item.ImageRectSize = Vector2.new(ImageSize.X/3, ImageSize.Y/3)
	end

	TopRight.ImageRectOffset     = Vector2.new(ImageSize.X * (2/3), 0)
	MiddleRight.ImageRectOffset  = Vector2.new(ImageSize.X * (2/3), ImageSize.Y/3)
	BottomRight.ImageRectOffset  = Vector2.new(ImageSize.X * (2/3), ImageSize.Y * (2/3))
	
	--TopLeft.ImageRectOffset    = Vector2.new(0, 0);
	MiddleLeft.ImageRectOffset   = Vector2.new(0, ImageSize.Y/3)
	BottomLeft.ImageRectOffset   = Vector2.new(0, ImageSize.Y * (2/3))
	
	Middle.ImageRectOffset       = Vector2.new(ImageSize.X/3, ImageSize.Y/3)
	MiddleTop.ImageRectOffset    = Vector2.new(0, ImageSize.Y/3)
	MiddleBottom.ImageRectOffset = Vector2.new(ImageSize.Y * (2/3), ImageSize.Y/3)

	return TopLeft, TopRight, BottomLeft, BottomRight, Middle, MiddleLeft, MiddleRight, MiddleTop, MiddleBottom
end
lib.AddNinePatch = AddNinePatch
lib.addNinePatch = AddNinePatch

return lib