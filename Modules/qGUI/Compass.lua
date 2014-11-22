local ReplicatedStorage       = game:GetService("ReplicatedStorage")

local NevermoreEngine         = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary       = NevermoreEngine.LoadLibrary

local qSystems                = LoadCustomLibrary("qSystems")
local qGUI                    = LoadCustomLibrary("qGUI")
local OverriddenConfiguration = LoadCustomLibrary("OverriddenConfiguration")

local Class = qSystems.Class
local Make = qSystems.Make

local lib = {}

-- Compass.lua
-- @author Quenty

local Tau = math.pi * 2

local function GetRotationDirection(LastRotation, CurrentRotation)
	--- Identifies the direction to rotate given the last rotation and the current rotation.
	-- @param LastRotation The last rotation (in radians).
	-- @param CurrentRotation The current rotation
	-- @return RotationDirection If positive, then you should add, otherwise, subtract (Will return 1 or -1)
	-- @return ChangeInRotation The amount changed (Basically, the difference between the two points). This is returned so you can
	--                        scale the compass. (In radians)


	local RotationDirection
	local Difference = math.abs(CurrentRotation - LastRotation) % Tau; 
	local ChangeInRotation = math.min(Tau - Difference, Difference) 

	if ((CurrentRotation - LastRotation + Tau) % Tau < math.pi) then
		RotationDirection = 1
	else
		RotationDirection = -1
	end

	return RotationDirection, ChangeInRotation
end
lib.GetRotationDirection = GetRotationDirection

local function GetCameraRotation(CoordinateFrame, Focus)
	-- Get's a camera's XZ plane rotation (Rotation along the Y axis) in radians
	-- @param CoordinateFrame The CoordinateFrame of the camera
	-- @param Focus The focus of the camera

	-- 0 degrees is north (I think?)

	return math.atan2(CoordinateFrame.X - Focus.X, CoordinateFrame.Z - Focus.Z) + math.pi
end
lib.GetCameraRotation = GetCameraRotation

local function GetRelativeAngle(Camera, TargetPosition)
	--- Get's the relative angle from the camera to a "target" position in the world coordinates.
	-- @param Camera The camera to get the relative angle on.
	-- @param TargetPosition The world target position.
	-- @pre Step has been called.

	local RelativeAngle = GetCameraRotation(Camera.CoordinateFrame, TargetPosition)
	-- print("RelativeAngle: " .. Round(RelativeAngle, 0.01) .. "; Angle: " .. Round(Angle, 0.01) .. "; Angle - RelativeAngle = " .. Round(Angle - RelativeAngle, 0.01))

	return RelativeAngle
end
lib.GetRelativeAngle = GetRelativeAngle

local MakeCompassModel = Class(function(CompassModel)
	--- This is an inertia model compass thing. 

	local SmoothnessFactor = 4 -- The "smoothing" factor of compass model. Increase for a faster speed.
	local RealAngle        = 0 -- The real angle of the camera.
	local Angle            = 0 -- Smoothed angle

	local LastUpdatePoint = tick()

	local function Step(Camera)
		--- Updates the compass, with "step." Should be called to refresh the model, and will update the spin accordingly.
		-- With a "low" step-time (that is, more than 1 second or something) compass may spin super fast, jumping around. Adjust smoothness factor or something to compensate.
		-- @param Camera The current camera.

		local CurrentTime = tick()
		local Delta = CurrentTime - LastUpdatePoint
		local Rotation = GetCameraRotation(Camera.CoordinateFrame, Camera.Focus)
		RealAngle = Rotation

		local Direction, ChangeInRotation = GetRotationDirection(Angle, Rotation)
		Angle = math.abs((Angle + Direction * ChangeInRotation * Delta * SmoothnessFactor) % Tau)


		LastUpdatePoint = CurrentTime

		return Angle, RealAngle
	end
	CompassModel.Step = Step
	CompassModel.step = Step

	local function GetAngle()
		--- Returns the smoothed angle 

		return Angle
	end
	CompassModel.GetAngle = GetAngle
	CompassModel.getAngle = GetAngle

	local function GetRealAngle()
		--- Return's the actual angle of the camera

		return RealAngle
	end
	CompassModel.GetRealAngle = GetRealAngle
	CompassModel.getRealAngle = GetRealAngle

	local function SetSmoothnessFactor(NewSmoothnessFactor)
		--- Set's the smoothness factor of the inertia compass.
		-- @param NewSmoothnessFactor The smoothness factor. (Number)

		assert(type(NewSmoothnessFactor) == "number")

		SmoothnessFactor = NewSmoothnessFactor
	end
	CompassModel.SetSmoothnessFactor = SetSmoothnessFactor
	CompassModel.setSmoothnessFactor = SetSmoothnessFactor

	local function GetRelativeAngle(Camera, TargetPosition)
		--- Get's the relative angle from the camera to a "target" position in the world coordinates.
		-- @param Camera The camera to get the relative angle on.
		-- @param TargetPosition The world target position.
		-- @pre Step has been called.

		-- assert(TargetPosition, "No TargetPosition")

		local RelativeAngle = GetCameraRotation(Camera.CoordinateFrame, TargetPosition) 
		-- print("RelativeAngle: " .. Round(RelativeAngle, 0.01) .. "; Angle: " .. Round(Angle, 0.01) .. "; Angle - RelativeAngle = " .. Round(Angle - RelativeAngle, 0.01))

		return RelativeAngle
	end
	CompassModel.GetRelativeAngle = GetRelativeAngle
	CompassModel.getRelativeAngle = GetRelativeAngle
end)
lib.MakeCompassModel = MakeCompassModel
lib.makeCompassModel = MakeCompassModel


local function GetPercentPosition(CurrentAngle, Angle, ThetaVisible)
	--- Get's a percent position for a GUI. Tries to handle the wrap-around based upon CurrentAngle and Angle.
	-- @param CurrentAngle The current angle of the compass.
	-- @param Angle The angle that the percent is needed.
	-- @param ThetaVisible The area shown by the compass (the rest will be hidden). (In radians)
	-- @return Percent in [0, 1]. May be greater than range (for scaling purposes). 

	local SmallBounds = Angle - ThetaVisible/2
	local RelativeAngle = CurrentAngle - SmallBounds
	local PercentPosition = RelativeAngle / ThetaVisible

	local MaximumPercent = Tau / ThetaVisible
	local SwitchPoint = MaximumPercent/2 -- The point left, or right, where it will "switch" over to be on the other side (Aka wrap around).

	if PercentPosition < -SwitchPoint + ThetaVisible/2 then -- Factor in the "shown" area to when it'll switch over.
		return PercentPosition + MaximumPercent
	elseif PercentPosition > SwitchPoint then
		return PercentPosition - MaximumPercent
	else
		return PercentPosition
	end
end
lib.GetPercentPosition = GetPercentPosition

local function GetGuiTransparency(PercentPosition, SolidArea)
	--- Return's a GUI's transparency based on it's percent position.

	local Distance = math.abs(0.5 - PercentPosition)
	local Range = SolidArea/2
	local ExternalRange = (1 - SolidArea)/2
	local Transparency = (Distance-Range) / ExternalRange

	if Transparency >= 1 then
		return 1
	elseif Transparency <= 0 then
		return 0
	else
		return Transparency
	end
end
lib.GetGuiTransparency = GetGuiTransparency


local MakeStripCompass = Class(function(StripCompass, Configuration)
	--- Makes a skyrim style "strip" compass.
	-- @param Configuration The configuration to use (overrides).

	local Configuration = OverriddenConfiguration.new(Configuration, {
		ThetaVisible     = math.pi/2; -- The area shown by the compass (the rest will be hidden). (In radians)
		SolidArea     = 0.8; -- Area in the center where GUIs are not transparent. (Percentage). (Will fade out to ends).
		ZIndex        = 1;
		DefaultWidth  = 300; -- The user can modify Container however they want, so these don't matter too much
		DefaultHeight = 40; -- The user can modify Container however they want, so these don't matter too much

		DefaultYOffset = 60;

		DefaultBackgroundTransparency = 0.8; -- Default BackgroundTransparency of the frame.
		MouseOverBackgroundTransparency = 0.3; -- Mouse over transparency.
		AnimationTime = 0.2; -- On mouse over. 
	})

	local Container = Make("Frame", {
		Archivable             = false;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = Configuration.DefaultBackgroundTransparency;
		BorderSizePixel        = 0;
		ClipsDescendants       = false;
		Name                   = "StripCompassFrame";
		Position               = UDim2.new(0.5, -Configuration.DefaultWidth/2, 0, Configuration.DefaultYOffset);
		Size                   = UDim2.new(0, Configuration.DefaultWidth, 0, Configuration.DefaultHeight);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex;
	})
	StripCompass.Gui = Container

	local CompassModel = MakeCompassModel()
	StripCompass.CompassModel = CompassModel

	local CurrentInterestPoints = {} -- Stores interest points in the world.
	local CurrentCoordinateDirections = {} -- Stores stuff like NSEW

	-- local function GetPercentPosition(CurrentAngle, Angle)
	-- 	--- Get's a percent position for a GUI. Tries to handle the wrap-around based upon CurrentAngle and Angle.
	-- 	-- @param CurrentAngle The current angle of the compass.
	-- 	-- @param Angle The angle that the percent is needed.
	-- 	-- @return Percent in [0, 1]. May be greater than range (for scaling purposes). 

	-- 	local SmallBounds = Angle - Configuration.ThetaVisible/2
	-- 	local RelativeAngle = CurrentAngle - SmallBounds
	-- 	local PercentPosition = RelativeAngle / Configuration.ThetaVisible

	-- 	-- We want to distribute the compass's "pointers" equally on both sides. So if the Angle is 

	-- 	-- Mental notes.
	-- 	-- Angle @ 180
	-- 	-- [0, 180] [180, 360]
	-- 	-- 

	-- 	-- Angle @ 270
	-- 	-- [90, 270] [270, 90]

	-- 	-- if Angle < CurrentAngle - 180 or Angle > CurrentAngle + 180 then we are on the opposite side. However, 
	-- 	-- if Angle is [90, 270]

	-- 	-- if Angle > CurrentAngle + math.pi then

	-- 	local MaximumPercent = Tau / Configuration.ThetaVisible
	-- 	local SwitchPoint = MaximumPercent/2 -- The point left, or right, where it will "switch" over to be on the other side (Aka wrap around).

	-- 	if PercentPosition < -SwitchPoint + Configuration.ThetaVisible/2 then -- Factor in the "shown" area to when it'll switch over.
	-- 		return PercentPosition + MaximumPercent
	-- 	elseif PercentPosition > SwitchPoint then
	-- 		return PercentPosition - MaximumPercent
	-- 	else
	-- 		return PercentPosition
	-- 	end
	-- end

	-- local function GetGuiTransparency(PercentPosition)
	-- 	--- Return's a GUI's transparency based on it's percent position.

	-- 	local Distance = math.abs(0.5 - PercentPosition)
	-- 	local Range = Configuration.SolidArea/2
	-- 	local ExternalRange = (1 - Configuration.SolidArea)/2
	-- 	local Transparency = (Distance-Range) / ExternalRange

	-- 	if Transparency >= 1 then
	-- 		return 1
	-- 	elseif Transparency <= 0 then
	-- 		return 0
	-- 	else
	-- 		return Transparency
	-- 	end
	-- end

	local function Step(Camera)
		--- Updates the compass model.
		-- @param Camera The current camera.

		local CurrentAngle, RealAngle = CompassModel.Step(Camera)
		-- print("[Compass] - CurrentAngle = " .. Round(CurrentAngle, 0.01) .. "; Real Angle = " .. Round(RealAngle, 0.01))

		for _, CoordinateDirection in pairs(CurrentCoordinateDirections) do
			local PercentPosition = GetPercentPosition(CurrentAngle, CoordinateDirection.Angle, Configuration.ThetaVisible)

			local Gui = CoordinateDirection.Gui
			Gui.Position = UDim2.new(PercentPosition, -Gui.AbsoluteSize.X/2, 0.5, -Gui.AbsoluteSize.Y/2)

			local Transparency = GetGuiTransparency(PercentPosition, Configuration.SolidArea)
			CoordinateDirection.SetTransparency(Gui, Transparency)
		end

		for _, InterestPoint in pairs(CurrentInterestPoints) do
			local RelativeAngle = CompassModel.GetRelativeAngle(Camera, InterestPoint.Point)
			local PercentPosition = GetPercentPosition(CurrentAngle, RelativeAngle, Configuration.ThetaVisible)

			local Gui = InterestPoint.Gui
			Gui.Position = UDim2.new(PercentPosition, -Gui.AbsoluteSize.X/2, 0.5, -Gui.AbsoluteSize.Y/2)

			local Transparency = GetGuiTransparency(PercentPosition, Configuration.SolidArea)
			InterestPoint.SetTransparency(Gui, Transparency)
		end
	end
	StripCompass.Step = Step
	StripCompass.step = Step

	local function AddCoordinateDirection(Angle, Gui, SetTransparency)
		--- Adds a new coordainte direction to the compass. 
		-- @param Angle Angle on the compass, relative to "N" (0 radians).
		-- @param Gui The Gui to display.
		-- @param SetTransparency Sets the transparency of the GUI. If not given, it will not set the transparency (and your GUI will look ugly.)


		local CoordinateDirection           = {}
		CoordinateDirection.Angle           = Angle
		CoordinateDirection.Gui             = Gui
		CoordinateDirection.SetTransparency = SetTransparency

		Gui.Parent = Container

		CurrentCoordinateDirections[Gui] = CoordinateDirection
	end
	StripCompass.AddCoordinateDirection = AddCoordinateDirection
	StripCompass.addCoordinateDirection = AddCoordinateDirection

	local function RemoveCoordinateDirection(Gui)
		--- Remove's a coordiante direction.
		-- @param Gui The Gui to remove (linked to the CoordinateDirection)

		if CurrentCoordinateDirections[Gui] then
			Gui.Parent = nil
			CurrentCoordinateDirections[Gui] = nil
		else
			error("[StripCompass] - Could not find CoordinateDirection with given GUI")
		end
	end
	StripCompass.RemoveCoordinateDirection = RemoveCoordinateDirection
	StripCompass.removeCoordinateDirection = RemoveCoordinateDirection

	local function AddInterestPoint(Point, Gui, SetTransparency)
		--- Adds a new interest point.
		-- @param Point A vector3 point (as the interest)
		-- @param Gui A GUI object to use as rendering.
		-- @param SetTransparency Sets the transparency of the GUI. If not given, it will not set the transparency (and your GUI will look ugly.)

		local NewInterestPoint           = {}
		NewInterestPoint.Point           = Point
		NewInterestPoint.Gui             = Gui
		NewInterestPoint.SetTransparency = SetTransparency

		Gui.Parent = Container

		CurrentInterestPoints[Gui] = NewInterestPoint
	end
	StripCompass.AddInterestPoint = AddInterestPoint
	StripCompass.addInterestPoint = AddInterestPoint

	local function RemoveInterestPoint(Gui)
		if CurrentInterestPoints[Gui] then
			Gui.Parent = nil
			CurrentInterestPoints[Gui] = nil
		else
			error("[StripCompass] - Could not identify InterestPoint with the given GUI")
		end
	end
	StripCompass.RemoveInterestPoint = RemoveInterestPoint
	StripCompass.removeInterestPoint = RemoveInterestPoint

	Container.MouseEnter:connect(function()
		qGUI.TweenTransparency(Container, {BackgroundTransparency = Configuration.MouseOverBackgroundTransparency}, Configuration.AnimationTime, true)
	end)

	Container.MouseLeave:connect(function()
		qGUI.TweenTransparency(Container, {BackgroundTransparency = Configuration.DefaultBackgroundTransparency}, Configuration.AnimationTime, true)
	end)
end)
lib.MakeStripCompass = MakeStripCompass
lib.makeStripCompass = MakeStripCompass

local MakeCircleCompass = Class(function(CircleCompass, Frame, Configuration)
	--- Makes a CircleCompass based around the ShipInterface circle system, where an arc is drawn from (through) the bottom left and right corners, that is
	-- tangent to the top of the frame.

	local Width            = Frame.Size.X.Offset
	local Height           = Frame.Size.Y.Offset -- CANNOT BE > WIDTH / 2. PANIC. PANIC. MAYBE. TREY IS CRAY CRAY
	local Radius           = (Height/2) + ((Width*Width)/(8 * Height)) 
		-- + Height/2 - 5 -- Adding Height/2 -5 so it is 5 below the top of the
	local ArcLength        = (2 * Height + Width*Width / (2 * Height)) * math.atan(2 * Height / Width )
	local ThetaVisible     = ArcLength/Radius -- Theta visible in the box.	(Number, will be [-HalfThetaVisible, HalfThetaVisible])
	local HalfThetaVisible = ThetaVisible/2

	local Configuration = OverriddenConfiguration.new(Configuration, {
		SolidArea     = 0.8; -- Area in the center where GUIs are not transparent. (Percentage). (Will fade out to ends).
	})

	local CompassModel = MakeCompassModel()
	CircleCompass.CompassModel = CompassModel

	local CurrentInterestPoints = {} -- Stores interest points in the world.
	local CurrentCoordinateDirections = {} -- Stores stuff like NSEW

	local function GetPositionAndRotation(Gui, PercentPosition)
		local RadianTheta  = HalfThetaVisible * (PercentPosition - 0.5)
		local NewLocationX = math.sin(RadianTheta) * Radius
		local NewLocationY = math.cos(RadianTheta) * Radius

		local Position = UDim2.new(0.5, NewLocationX - Gui.Size.X.Offset/2, 0, Radius - NewLocationY)
		local Rotation = RadianTheta * 180 / math.pi

		return Position, Rotation
	end

	local function Step(Camera)
		--- Updates the compass model.
		-- @param Camera The current camera.

		local CurrentAngle, RealAngle = CompassModel.Step(Camera)
		-- print("[Compass] - CurrentAngle = " .. Round(CurrentAngle, 0.01) .. "; Real Angle = " .. Round(RealAngle, 0.01))

		for _, CoordinateDirection in pairs(CurrentCoordinateDirections) do
			local PercentPosition = GetPercentPosition(CurrentAngle, CoordinateDirection.Angle, ThetaVisible)

			local Gui = CoordinateDirection.Gui
			local Position, Rotation = GetPositionAndRotation(Gui, PercentPosition)
			Gui.Position = Position
			Gui.Rotation = Rotation

			local Transparency = GetGuiTransparency(PercentPosition, Configuration.SolidArea)
			CoordinateDirection.SetTransparency(Gui, Transparency)
		end

		for _, InterestPoint in pairs(CurrentInterestPoints) do
			--assert(InterestPoint.Point, "No point")

			local RelativeAngle = CompassModel.GetRelativeAngle(Camera, InterestPoint.Point)
			local PercentPosition = GetPercentPosition(CurrentAngle, RelativeAngle, ThetaVisible)

			local Gui = InterestPoint.Gui
			local Position, Rotation = GetPositionAndRotation(Gui, PercentPosition)
			Gui.Position = Position
			Gui.Rotation = Rotation

			local Transparency = GetGuiTransparency(PercentPosition, Configuration.SolidArea)
			InterestPoint.SetTransparency(Gui, Transparency)
		end
	end
	CircleCompass.Step = Step
	CircleCompass.step = Step

	local function AddCoordinateDirection(Angle, Gui, SetTransparency)
		--- Adds a new coordainte direction to the compass. 
		-- @param Angle Angle on the compass, relative to "N" (0 radians).
		-- @param Gui The Gui to display.
		-- @param SetTransparency Sets the transparency of the GUI. If not given, it will not set the transparency (and your GUI will look ugly.)

		local CoordinateDirection           = {}
		CoordinateDirection.Angle           = Angle
		CoordinateDirection.Gui             = Gui
		CoordinateDirection.SetTransparency = SetTransparency

		Gui.Parent = Frame

		CurrentCoordinateDirections[Gui] = CoordinateDirection
	end
	CircleCompass.AddCoordinateDirection = AddCoordinateDirection
	CircleCompass.addCoordinateDirection = AddCoordinateDirection

	local function UpdateCoordinateDirection(Gui, NewAngle)
		CurrentCoordinateDirections[Gui].Angle = NewAngle
	end
	CircleCompass.UpdateCoordinateDirection = UpdateCoordinateDirection
	CircleCompass.UpdateCoordinateDirection = UpdateCoordinateDirection

	local function RemoveCoordinateDirection(Gui)
		--- Remove's a coordiante direction.
		-- @param Gui The Gui to remove (linked to the CoordinateDirection)

		if CurrentCoordinateDirections[Gui] then
			Gui.Parent = nil
			CurrentCoordinateDirections[Gui] = nil
		else
			error("[CircleCompass] - Could not find CoordinateDirection with given GUI")
		end
	end
	CircleCompass.RemoveCoordinateDirection = RemoveCoordinateDirection
	CircleCompass.removeCoordinateDirection = RemoveCoordinateDirection

	local function AddInterestPoint(Point, Gui, SetTransparency)
		--- Adds a new interest point.
		-- @param Point A vector3 point (as the interest)
		-- @param Gui A GUI object to use as rendering.
		-- @param SetTransparency Sets the transparency of the GUI. If not given, it will not set the transparency (and your GUI will look ugly.)

		assert(Point, "No point!")

		local NewInterestPoint           = {}
		NewInterestPoint.Point           = Point
		NewInterestPoint.Gui             = Gui
		NewInterestPoint.SetTransparency = SetTransparency

		Gui.Parent = Frame

		CurrentInterestPoints[Gui] = NewInterestPoint
	end
	CircleCompass.AddInterestPoint = AddInterestPoint
	CircleCompass.addInterestPoint = AddInterestPoint

	local function UpdateInterestPoint(Gui, NewPoint)
		CurrentInterestPoints[Gui].Point = NewPoint
	end
	CircleCompass.UpdateInterestPoint = UpdateInterestPoint
	CircleCompass.updateInterestPoint = UpdateInterestPoint

	local function RemoveInterestPoint(Gui)
		if CurrentInterestPoints[Gui] then
			Gui.Parent = nil
			CurrentInterestPoints[Gui] = nil
		else
			error("[CircleCompass] - Could not identify InterestPoint with the given GUI")
		end
	end
	CircleCompass.RemoveInterestPoint = RemoveInterestPoint
	CircleCompass.removeInterestPoint = RemoveInterestPoint
end)
lib.MakeCircleCompass = MakeCircleCompass
lib.makeCircleCompass = MakeCircleCompass

return lib