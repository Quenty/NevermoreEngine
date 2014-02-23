local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems = LoadCustomLibrary("qSystems")
local qGUI     = LoadCustomLibrary("qGUI")

qSystems:Import(getfenv(0));

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

local function GetCameraRotation(CoordinateFrame, Focus)
	-- Get's a camera's XZ plane rotation (Rotation along the Y axis) in radians
	-- @param CoordinateFrame The CoordinateFrame of the camera
	-- @param Focus The focus of the camera

	-- 0 degrees is north (I think?)

	return math.abs(math.atan2(math.rad(CoordinateFrame.X - Focus.X), math.rad(CoordinateFrame.Z - Focus.Z))) % 360
end

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
		Angle = Angle + Direction * ChangeInRotation * Delta * SmoothnessFactor

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
		-- @param NewSmoothnessFactor A number, the new smoothness factor.

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

		local RelativeAngle = GetCameraRotation(Camera.CoordinateFrame, TargetPosition)
		return Angle - RelativeAngle
	end
	CompassModel.GetRelativeAngle = GetRelativeAngle
	CompassModel.getRelativeAngle = GetRelativeAngle
end)
lib.MakeCompassModel = MakeCompassModel
lib.makeCompassModel = MakeCompassModel

local MakeStripCompass = Class(function(StripCompass)
	--- Makes a skyrim style "strip" compass.

	local Configuration = {
		ShownArea     = math.pi/2; -- The area shown by the compass (the rest will be hidden). (In radians)
		SolidArea     = 0.8; -- Area in the center where GUIs are not transparent. (Percentage). (Will fade out to ends).
		ZIndex        = 5;
		DefaultWidth  = 200; -- The user can modify Container however they want, so these don't matter too much
		DefaultHeight = 40; -- The user can modify Container however they want, so these don't matter too much

		DefaultBackgroundTransparency = 0.8; -- Default BackgroundTransparency of the frame.
		MouseOverBackgroundTransparency = 0.3; -- Mouse over transparency.
		AnimationTime = 0.2; -- On mouse over. 
	}

	local Container = Make 'Frame' {
		Archivable             = false;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = Configuration.DefaultBackgroundTransparency;
		BorderSizePixel        = 0;
		ClipsDescendents       = true;
		Name                   = "StripCompassFrame";
		Position               = UDim2.new(0.5, -Container.DefaultWidth/2, 0, Container.DefaultHeight)
		Size                   = UDim2.new(0, Configuration.DefaultWidth, 0, Configuration.DefaultHeight);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex;
	}
	StripCompass.Gui = Container

	local CompassModel = MakeCompassModel()
	StripCompass.CompassModel = CompassModel

	local CurrentInterestPoints = {} -- Stores interest points in the world.
	local CurrentCoordinateDirections = {} -- Stores stuff like NSEW

	local function GetPercentPosition(CurrentAngle, Angle)
		--- Get's a percent position for a GUI
		-- @param CurrentAngle The current angle of the compass.
		-- @param Angle The angle that the percent is needed.
		-- @return Percent in [0, 1]. May be greater than range (for scaling purposes). 

		local SmallBounds = Angle + Configuration.ShownArea/2
		local RelativeAngle = CurrentAngle - SmallBounds
		-- if RelativeAngle < 0 or RelativeAngle > Configuration.ShownArea then
			-- return nil
		-- else
		return RelativeAngle / Configuration.ShownArea
		-- end
	end

	local function GetGuiTransparency(PercentPosition)
		--- Return's a GUI's transparency based on it's percent position.

		local Distance = math.abs(0.5 - PercentPosition)
		local Range = Configuration.SolidArea/2

		return math.min(1, Distance/Range)
	end

	local function Step(Camera)
		--- Updates the compass model.
		-- @param Camera The current camera.

		local CurrentAngle = CompassModel.Step(Camera)

		for _, CoordinateDirection in pairs(CurrentInterestPoints) do
			local PercentPosition = GetPercentPosition(CurrentAngle, CoordinateDirection.Angle)

			local Gui = CoordinateDirection.Gui
			Gui.Position = UDim2.new(PercentPosition, -Gui.AbsoluteSize.X/2, 0.5, -Gui.AbsoluteSize.Y/2)

			local Transparency = GetGuiTransparency(PercentPosition)
			CoordinateDirection.SetTransparency(Transparency)
		end

		for _, InterestPoint in pairs(CurrentInterestPoints) do
			local RelativeAngle = CompassModel.GetRelativeAngle(Camera, InterestPoint.Point)
			local PercentPosition = GetPercentPosition(CurrentAngle, RelativeAngle)

			local Gui = InterestPoint.Gui
			Gui.Position = UDim2.new(PercentPosition, -Gui.AbsoluteSize.X/2, 0.5, -Gui.AbsoluteSize.Y/2)

			local Transparency = GetGuiTransparency(PercentPosition)
			InterestPoint.SetTransparency(Transparency)
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

return lib