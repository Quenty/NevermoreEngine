local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local Table             = LoadCustomLibrary("Table")

local Make              = qSystems.Make
local Modify            = qSystems.Modify


local lib = {}

local WEAK_MODE = {
	K  = {__mode="k"};
	V  = {__mode="v"};
	KV = {__mode="kv"};
}


-- qGUI.lua
-- @author Quenty
-- A group of utility functions to be used to help create visual effectcs with ROBLOX GUIs

--[[

Change Log
November 17th, 2014
- Removed importing into the environment

September 9th, 2014
- Optimized tweening for GUIs with time less than 0

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
lib.get_screen = GetScreen

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
lib.center = Center

local function PointInBounds(Frame, X, Y)
	local TopBound    = Frame.AbsolutePosition.Y
	local BottomBound = Frame.AbsolutePosition.Y + Frame.AbsoluteSize.Y
	local LeftBound   = Frame.AbsolutePosition.X
	local RightBound  = Frame.AbsolutePosition.X + Frame.AbsoluteSize.X

	if Y > TopBound and Y < BottomBound and X > LeftBound and X < RightBound then
		return true
	else
		return false
	end
end
lib.PointInBounds = PointInBounds

local function MouseOver(Mouse, Frame)
	return PointInBounds(Frame, Mouse.X, Mouse.Y)
end
lib.MouseOver = MouseOver
lib.mouseOver = MouseOver
lib.mouse_over = MouseOver

--[[
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
lib.inverse_color3 = InverseColor3--]]

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

--[[ -- Use new camera API instead
local function WorldToScreen(ScreenSize, Camera, Position)
	--- Converts a 3D point to a 2D point on the screen. 
	-- @param ScreenSize Vector2, the current screensize.
	-- @param Camera The current camera (to do the operation on)
	-- @param Position = The Vector3 position
	-- @return X (In scale), Y (in scale) and Z (Stud distance))

	-- Credit to TreyReynolds for magic.

	local VSY              = ScreenSize.Y
	local CoordinateFrame  = Camera.CoordinateFrame
	
	local ScreenLimitY     = math.tan(math.rad(Camera.FieldOfView)/2)*2
	-- local ScreenLimitX     = ScreenLimitY*Mouse.ViewSizeX/VSY
	
	local RelativePosition = CoordinateFrame:inverse() * Position

	return 0.5 - RelativePosition.x/RelativePosition.z/(ScreenLimitY*ScreenSize.X/VSY), 0.5 + RelativePosition.y/RelativePosition.z/ScreenLimitY, -RelativePosition.z
end

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
EndValue


lib.WorldToScreen = WorldToScreen
lib.worldToScreen = WorldToScreen
lib.world_to_screen = WorldToScreen
--]]
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

local TweenTransparency, StopTransparencyTween do
	local IsLocal = game:FindService("MeshContentProvider") ~= nil or (game:FindService("NetworkServer") == nil)
	print("[qGUI]- IsLocal is " .. tostring(IsLocal))

	local ProcessList = {}
	local ProcessingList = false

	local function SetProperties(Gui, Percent, StartProperties, NewProperties)
		-- Maybe there's a better way to do this?

		for Index, EndValue in next, NewProperties do
			local StartProperty = StartProperties[Index]
			Gui[Index] = StartProperty + (EndValue - StartProperty) * Percent
		end
	end

	local function UpdateTweenModels()
		-- @return Boolean, DidUpdate, whether it updated or not.

		local CurrentTick = tick()
		local DidUpdate = false

		for Gui, TweenState in next, ProcessList do
			if Gui:IsDescendantOf(game) then
				DidUpdate = true

				local TimeElapsed = (CurrentTick - TweenState.StartTime)
				local Duration    = TweenState.Duration

				if TimeElapsed > Duration then -- Then we end it.
					SetProperties(Gui, 1, TweenState.StartProperties, TweenState.NewProperties) 
					ProcessList[Gui] = nil
				else -- Otherwise do the animations.
					SetProperties(Gui, TimeElapsed/Duration, TweenState.StartProperties, TweenState.NewProperties)
				end
			else
				ProcessList[Gui] = nil
			end
		end

		return DidUpdate
	end

	local function StartProcessUpdate()
		-- ProcessingList stores state of processing.

		if not (ProcessingList) then
			ProcessingList = true
			
			if IsLocal then
				local UpdateName = "TweenTransparencyOnGuis" .. tick()

				RunService:BindToRenderStep(UpdateName, 2000, function()
					local DidUpdate = UpdateTweenModels()
					if not DidUpdate then
						ProcessingList = false
						RunService:UnbindFromRenderStep(UpdateName)
					end
				end)
			else
				local DidDoIt, Error = coroutine.resume(coroutine.create(function()
					local DidUpdate
					repeat
						DidUpdate = UpdateTweenModels()
					until (not DidUpdate) and wait(0.05) -- repeat until DidUpdate is false. 

					ProcessingList = false
				end))

				if not DidDoIt then
					ProcessingList = false
					error(Error)
				end
			end
		end
	end

	function TweenTransparency(Gui, NewProperties, Duration, Override)
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
			if Duration <= 0 then
				warn("[TweenTransparency] - Duration <= 0")
				SetProperties(Gui, 1, NewProperties, NewProperties)
			else
				-- Fill StartProperties
				local StartProperties = {}
				local CopiedNewProperties = {}

				for Index, Value in pairs(NewProperties) do
					if Gui[Index] ~= Value then
						StartProperties[Index] = Gui[Index]
						CopiedNewProperties[Index] = Value
					-- else
					-- 	warn("Number " .. Index .. " of " .. Gui:GetFullName() .. " is not changing. @" .. tostring(Value))
					end
				end

				-- And set NewState
				local NewState = {
					StartTime       = tick();
					Duration        = Duration or error("No duration");
					StartProperties = StartProperties;
					NewProperties   = CopiedNewProperties;
				}

				ProcessList[Gui] = NewState
				StartProcessUpdate()
			end
		end
	end

	function StopTransparencyTween(Gui)
		-- Overrides all the current transparency animations in a GUI. Perhaps useful.
		-- @param Gui The GUI to stop the tween the Transparency's upon

		ProcessList[Gui] = nil
	end


	lib.TweenTransparency = TweenTransparency
	lib.tweenTransparency = TweenTransparency

	lib.StopTransparencyTween = StopTransparencyTween
	lib.stopTransparencyTween = StopTransparencyTween
end

local TweenColor3, StopColor3Tween do
	local IsLocal = game:FindService("MeshContentProvider") ~= nil or (game:FindService("NetworkServer") == nil)
	local ProcessList = {}
	-- setmetatable(ProcessList, WEAK_MODE.K)
	local ActivelyProcessing = false


	local function LerpNumber(ValueOne, ValueTwo, Alpha)
		--- From qMath

		return ValueOne + ((ValueTwo - ValueOne) * Alpha)
	end

	local function LerpColor3(ColorOne, ColorTwo, Alpha)
		--- From qColor3
		
		return Color3.new(LerpNumber(ColorOne.r, ColorTwo.r, Alpha), LerpNumber(ColorOne.g, ColorTwo.g, Alpha), LerpNumber(ColorOne.b, ColorTwo.b, Alpha))
	end

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
			if Gui and Gui:IsDescendantOf(game) then
				ActivelyProcessing = tick()

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
		if not (ActivelyProcessing and ActivelyProcessing + 0.1 >= tick()) then
			ActivelyProcessing = tick()
			assert(coroutine.resume(coroutine.create(function()
				while ActivelyProcessing do
					UpdateTweenModels()
					-- wait(0.05)
					if IsLocal then
						RunService.RenderStepped:wait()
					else
						wait(0.05)
					end
				end
			end)))
		end
	end
	
	function TweenColor3(Gui, NewProperties, Duration, Override)
		--- Tween's the Color3 values in a GUI,
		-- @param Gui The GUI to tween the Color3's upon
		-- @param NewProperties The properties to be changed. It will take the current
		--                      properties and tween to the new ones. This table should be
		--                      setup so {Index = NewValue} that is, for example, 
		--                      {BackgroundColor3 = Color3.new(1, 1, 1)}.
		-- @param Duration The amount of time to spend transitioning.
		-- @param [Override] If true, it will override a previous animation, otherwise, it will not.

		if not ProcessList[Gui] or Override then
			if Duration <= 0 then
				SetProperties(Gui, 1, NewProperties, NewProperties)
			else
				-- Fill StartProperties
				local StartProperties = {}
				local CopiedNewProperties = {}

				for Index, Value in pairs(NewProperties) do
					if Gui[Index] ~= Value then
						StartProperties[Index] = Gui[Index]
						CopiedNewProperties[Index] = Value
					-- else
					-- 	warn("Color3", Index, " of", Gui:GetFullName(), " is not changing")
					end
				end

				-- And set NewState
				local NewState = {
					StartTime       = tick();
					Duration        = Duration or error("No duration");
					StartProperties = StartProperties;
					NewProperties   = CopiedNewProperties;
				}

				ProcessList[Gui] = NewState
				StartProcessUpdate()
			end
		end
	end

	function StopColor3Tween(Gui)
		-- Overrides all the current animations of Color3 in the GUI. 
		-- @param Gui The GUI to stop the tween animations on

		ProcessList[Gui] = nil
	end

	lib.TweenColor3 = TweenColor3
	lib.tweenColor3 = TweenColor3

	lib.StopColor3Tween = StopColor3Tween
	lib.stopColor3Tween = StopColor3Tween
end

local function ResponsiveCircleClickEffect(Gui, X, Y, Time, DoNotConstrainEffect, OverrideSize, InkColor)
	--- Google design thing. Actually, it's ink. :P
	-- @param DoNotConstrainEffect If set to true, it will not constrain the effect within the GUI.
	-- @param OverrideSize An overridden size.

	Time = Time or 0.6;

	X = X or Gui.AbsolutePosition.X + Gui.AbsoluteSize.X/2
	Y = Y or Gui.AbsolutePosition.Y + Gui.AbsoluteSize.Y/2

	X = X - Gui.AbsolutePosition.X
	Y = Y - Gui.AbsolutePosition.Y

	local StartDiameter = 6;

	local ParentFrame
	if not DoNotConstrainEffect then
		ParentFrame                        = Instance.new("Frame", Gui)
		ParentFrame.ClipsDescendants       = true;
		ParentFrame.Archivable             = false;
		ParentFrame.BorderSizePixel        = 0;
		ParentFrame.BackgroundTransparency = 1;
		ParentFrame.Name                   = "Circle_Effect";
		ParentFrame.Size                   = UDim2.new(1, 0, 1, 0);
		ParentFrame.ZIndex                 = math.min(Gui.ZIndex + 1, 10)
		ParentFrame.Parent                 = Gui;
	end

	local Circle                  = Instance.new("ImageLabel");
	Circle.Image                  = "http://www.roblox.com/asset/?id=172318712"
	Circle.Name                   = "Circle";
	Circle.ImageTransparency      = 0.75;
	Circle.BackgroundTransparency = 1;
	Circle.BorderSizePixel        = 0;
	Circle.Archivable             = false;
	Circle.Size                   = UDim2.new(0, StartDiameter, 0, StartDiameter);
	Circle.ZIndex                 = math.min(Gui.ZIndex + 1, 10)
	Circle.ImageColor3            = InkColor or Color3.new(1, 1, 1)
	Circle.Position               = UDim2.new(0, X-StartDiameter/2, 0, Y-StartDiameter/2)

	--[[if Gui.AbsoluteSize.X > Gui.AbsoluteSize.Y then
		Gui.SizeConstraint = "RelativeXX"
	else
		Gui.SizeConstraint = "RelativeYY"
	end--]]

	local NewDiameter
	if OverrideSize then
		NewDiameter = OverrideSize
	else
		NewDiameter = math.max(Gui.AbsoluteSize.X, Gui.AbsoluteSize.Y) * 2 * 2.82842712475-- multiply times 2 because we want it resize for the whole time, and at 1/2 we expect it to fill the whole place.
	end

	local NewSize     = UDim2.new(0, NewDiameter, 0,  NewDiameter)
	local NewPosition = UDim2.new(0, X - (NewDiameter / 2), 0, Y - (NewDiameter / 2))
	
	Circle.Parent                      = ParentFrame or Gui
	

	Circle:TweenSizeAndPosition(NewSize, NewPosition, "Out", "Linear", Time, true)
	TweenTransparency(Circle, {ImageTransparency = 0.5}, Time/3, true)
	delay(Time/3, function()
		TweenTransparency(Circle, {ImageTransparency = 1}, Time*2/3, true)
		wait(Time*2/3 + 0.1)

		if ParentFrame then
			ParentFrame:Destroy()
		else
			Circle:Destroy()
		end
	end)

	return ParentFrame or Circle
end
lib.ResponsiveCircleClickEffect = ResponsiveCircleClickEffect
lib.SimpleInk = ResponsiveCircleClickEffect

local function GenerateMouseDrag()
	-- Generate's a dragger to catch the mouse...
	return Make("ImageButton", {
		Active                 = false;
		Size                   = UDim2.new(1.5, 0, 1.5, 0);
		AutoButtonColor        = false;
		BackgroundTransparency = 1;
		Name                   = "MouseDrag";
		Position               = UDim2.new(-0.25, 0, -0.25, 0);
		ZIndex                 = 10;
	})
end
lib.GenerateMouseDrag = GenerateMouseDrag
lib.generateMouseDrag = GenerateMouseDrag

local function AddTexturedWindowTemplate(Frame, Radius, Type)
	-- Makes a 'Textured' window...  9Scale thingy?

	return Make(Type or 'Frame', {
		Archivable             = false;
		BackgroundColor3       = Frame.BackgroundColor3;
		BorderSizePixel        = 0;
		Parent                 = Frame;
		BackgroundTransparency = 1;
		ZIndex                 = Frame.ZIndex;
	},
		{Name = "TopLeft";	Position = UDim2.new(0, 0, 0, 0);		Size = UDim2.new(0, Radius, 0, Radius)},
		{Name = "BottomLeft";	Position = UDim2.new(0, 0, 1, -Radius);		Size = UDim2.new(0, Radius, 0, Radius)},
		{Name = "TopRight";	Position = UDim2.new(1, -Radius, 0, 0);		Size = UDim2.new(0, Radius, 0, Radius)},
		{Name = "BottomRight";	Position = UDim2.new(1, -Radius, 1, -Radius);	Size = UDim2.new(0, Radius, 0, Radius)},
		{Name = "Middle";	Position = UDim2.new(0, Radius, 0, 0);		Size = UDim2.new(1, -Radius*2, 1, 0  )},
		{Name = "MiddleLeft";	Position = UDim2.new(0, 0, 0, Radius);		Size = UDim2.new(0, Radius, 1, -Radius*2)},
		{Name = "MiddleRight";	Position = UDim2.new(1, -Radius, 0, Radius);	Size = UDim2.new(0, Radius, 1, -Radius*2)}
	)
end
lib.AddTexturedWindowTemplate = AddTexturedWindowTemplate
lib.addTexturedWindowTemplate = AddTexturedWindowTemplate

local function AddNinePatch(Frame, Image, ImageSize, Radius, Type, Properties)
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

	local MiddleTop = Make(Type, {
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

	local MiddleBottom = Make(Type, {
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
	MiddleTop.ImageRectOffset    = Vector2.new(ImageSize.Y/3, 0)
	MiddleBottom.ImageRectOffset = Vector2.new(ImageSize.Y/3, ImageSize.Y * (2/3))

	return TopLeft, TopRight, BottomLeft, BottomRight, Middle, MiddleLeft, MiddleRight, MiddleTop, MiddleBottom
end
lib.AddNinePatch = AddNinePatch
lib.addNinePatch = AddNinePatch

local function BackWithRoundedRectangle(Frame, Radius, Color)
	Color = Color or Color3.new(1, 1, 1);

	return AddNinePatch(Frame, "rbxassetid://176688412", Vector2.new(150, 150), Radius, "ImageLabel", {
		ImageColor3 = Color;
	})
end
lib.BackWithRoundedRectangle = BackWithRoundedRectangle

return lib
