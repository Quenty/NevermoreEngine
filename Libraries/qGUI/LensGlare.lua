local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")
local Players          = game:GetService("Players")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local qGUI              = LoadCustomLibrary("qGUI")
local qCFrame           = LoadCustomLibrary("qCFrame")
local qMath             = LoadCustomLibrary("qMath")

qSystems:Import(getfenv(0));

local lib = {}

--- This library not only handles glare, but also handles lens flares. Huzzah!
-- LensGlare.lua
-- @author Quenty
-- Last Modified February 3rd, 2014

local function IsNight()
	local MinutesAfterMidnight = Lighting:GetMinutesAfterMidnight()
	return MinutesAfterMidnight <= 345 or MinutesAfterMidnight >= 1110
end

local function GetSunPositionOnScreenRelativeToCamera(Camera, Magnitude)
	-- Only used for lens flare effect, I suppose...  Does what it's name says... 
	-- Magnitude is how far away from the camera the part will be rendered.

	Magnitude = Magnitude or 10
	
	return CFrame.new(Camera.CoordinateFrame.p, Camera.CoordinateFrame.p + Lighting:GetSunDirection()) * CFrame.new(0, 0, -(Magnitude - 1))
end
lib.GetSunPositionOnScreenRelativeToCamera = GetSunPositionOnScreenRelativeToCamera


local MakeLensGlare = Class(function(LensGlare, ScreenGui) 
	-- Makes a lensflare. Update() should be called every frame or so. 

	local Gui = Make 'Frame' {
		Archivable             = false;
		BackgroundColor3       = Color3.new(1, 1, 1);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "LensGlare";
		Parent                 = ScreenGui;
		Position               = UDim2.new(0, 0, 0, -2);
		Size                   = UDim2.new(1, 0, 1, 2);
		Visible                = true;
		ZIndex                 = 1;
	}

	LensGlare.Gui = Gui

	local function Step(Mouse)

		local CameraAngle = (Workspace.CurrentCamera.CoordinateFrame.p - Workspace.CurrentCamera.Focus.p).unit
		local SunAngleUnit = Lighting:GetSunDirection()

		

		--print("[LensGlare] - Transparency = " .. Transparency.." magnitude: "..(SunAngleUnit - CameraAngle).magnitude)
		if not IsNight() then
			local Transparency = 1.45 - (SunAngleUnit - CameraAngle).magnitude / 3

			local SunPositionGlobal = GetSunPositionOnScreenRelativeToCamera(Workspace.CurrentCamera, 10).p
			local SunIsOnScreen, SunPositionOnScreen, Angle = qGUI.WorldToScreen(SunPositionGlobal, Mouse, Workspace.CurrentCamera)
			if SunIsOnScreen then
				Gui.BackgroundTransparency = Transparency
			else
				Gui.BackgroundTransparency = 1
			end
		else
			Gui.BackgroundTransparency = 1
		end
	end

	LensGlare.Step = Step
end)
lib.MakeLensGlare = MakeLensGlare
lib.makeLensGlare = MakeLensGlare


local MakeLensFlare = Class(function(LensFlare, ScreenGui)
	-- Generates lens flare GUI's, and repositions them every time Step() is called.
	local Configuration = {
		SunFlareSizeMax = 80;
		SunFlareEndSizeMax = 60;
		SmallPieces = 5; -- How many pieces inbetween
		SmallPieceSizeMin = 40;
		SmallPieceSizeMax = 60;
		MaxTransparency = 0.7;
	}

	local ColorList = {
		qGUI.NewColor3(170, 170, 255);
		qGUI.NewColor3(170, 255, 127);
		qGUI.NewColor3(255, 170, 127);
		qGUI.NewColor3(255, 170, 255);
		qGUI.NewColor3(255, 255, 127);
		qGUI.NewColor3(255, 255, 255);
		qGUI.NewColor3(255, 170, 000);
	}

	local Guis = {}
	Guis.Container = Make 'Frame' {
		Archivable             = false;
		BackgroundColor3       = Color3.new(1, 1, 1);
		BackgroundTransparency = 1;
		Name                   = "qLensFlare";
		Parent                 = ScreenGui;
		Size                   = UDim2.new(1, 0, 1, 0);
		Visible                = true;
	}
	Guis.SunFlare = Make 'Frame' { -- Flare on the sun. 
		BackgroundColor3       = qGUI.PickRandomColor3(ColorList);
		BackgroundTransparency = 0.7;
		BorderSizePixel        = 0;
		Name                   = "LargeLensFlare";
		Parent                 = Guis.Container;
		Size                   = UDim2.new(0, Configuration.SunFlareSizeMax, 0, Configuration.SunFlareSizeMax);
		Visible                = true;
		ZIndex = 2;
	}
	Guis.SunFlareEnd = Make 'Frame' { -- Flare on the sun. 
		BackgroundColor3       = qGUI.PickRandomColor3(ColorList);
		BackgroundTransparency = 0.7;
		BorderSizePixel        = 0;
		Name                   = "LargeLensFlareEnd";
		Parent                 = Guis.Container;
		Size                   = UDim2.new(0, Configuration.SunFlareEndSizeMax, 0, Configuration.SunFlareEndSizeMax);
		Visible                = true;
	}
	Guis.SmallGuys = {} -- All those small little guys between the 2 large glares. 
	for Index = 1, Configuration.SmallPieces do
		local Size = math.random(Configuration.SmallPieceSizeMin)
		Guis.SmallGuys[Index] = {
			Gui = Make 'Frame' { -- Flare on the sun. 
				BackgroundColor3       = qGUI.PickRandomColor3(ColorList);
				BackgroundTransparency = 0.8;
				BorderSizePixel        = 0;
				Name                   = "SmallGuyInbetweenFlare"..Index;
				Parent                 = Guis.Container;
				Size                   = UDim2.new(0, Size, 0, Size);
				Visible                = true;
			};
			Size = Size;
		}
	end

	LensFlare.Guis = Guis

	local function PositionSunFlareFromCartisian2(SunFlareFrame, SunPositionVector2, SizeFactor, DefaultSize)
		--local SunPositionVector2 = qMath.Cartisian2ToVector(SunPositionCartisian2, ScreenMiddle)
		local Size = DefaultSize * SizeFactor -- 1 = full size (Direct look at sun), 0 = not shown 
		SunFlareFrame.Transparency = 1 - ((SizeFactor) * (1 - Configuration.MaxTransparency)) 
		SunFlareFrame.Size = UDim2.new(0, Size, 0, Size)
		SunFlareFrame.Position = qGUI.UDim2OffsetFromVector2(SunPositionVector2) - qGUI.GetHalfSize(SunFlareFrame);
	end

	local function Render(SunPositionVector2, Mouse, DoRender)
		-- Incrediably confusing/annoying vector math. :D
		-- Render's / Positions the GUI's... Called each step. SunPositionVector2 is the position of the sun on the screen, offset. 

		if DoRender then
			local ScreenMiddle = Vector2.new(Mouse.ViewSizeX, Mouse.ViewSizeY) / 2
			local SizeFactor = 1 - math.min(1, (ScreenMiddle - SunPositionVector2).magnitude / (Mouse.ViewSizeX/2)) -- So at the outside edge, it's 0, and at the center, it's 1
			--print("[LensGlare] - SizeFactor: " .. SizeFactor)
			local SunPositionCartisian2 = qMath.Vector2ToCartisian(SunPositionVector2, ScreenMiddle) -- Convert to cartisians so we can work with the middle of the screen, due to the nature of lens flares. 
			local EndSunPositionCartisian2 = qMath.InvertCartisian2(SunPositionCartisian2) -- Invert it...

			PositionSunFlareFromCartisian2(Guis.SunFlare, SunPositionVector2, SizeFactor, Configuration.SunFlareSizeMax)
			PositionSunFlareFromCartisian2(Guis.SunFlareEnd, qMath.Cartisian2ToVector(EndSunPositionCartisian2, ScreenMiddle), SizeFactor, Configuration.SunFlareEndSizeMax)

			for Index = 1, Configuration.SmallPieces do
				local SmallGuy = Guis.SmallGuys[Index]
				local PositionFactor = 1 - (((Index/(Configuration.SmallPieces+2) + (1/Configuration.SmallPieces))) * 2) -- 1 - (1/12 - 11/12, 1 spacing on both sides) * 2
				local SmallGuyCartisian2 = SunPositionCartisian2 * PositionFactor
				local Position = qMath.Cartisian2ToVector(SmallGuyCartisian2, ScreenMiddle)
				PositionSunFlareFromCartisian2(SmallGuy.Gui, Position, SizeFactor, SmallGuy.Size)
			end
			--Guis.SunFlare.Position = qGUI.UDim2OffsetFromVector2(SunPositionVector2) - qGUI.GetHalfSize(Guis.SunFlare);
			--Guis.SunFlareEndqGUI.UDim2OffsetFromVector2(EndSunPositionCartisian2) 
		else
			Guis.SunFlare.BackgroundTransparency = 1
			Guis.SunFlareEnd.BackgroundTransparency = 1
			for Index = 1, Configuration.SmallPieces do
				local SmallGuy = Guis.SmallGuys[Index]
				SmallGuy.Gui.BackgroundTransparency = 1
			end
		end
	end

	local function Step(Mouse)
		assert(Mouse, "[LensFlare] - Mouse is nil")

		local Ray = Ray.new( -- We need to ray cast to see if the sun is being blocked at all...
			Workspace.CurrentCamera.CoordinateFrame.p,
			(Workspace.CurrentCamera.CoordinateFrame.p -  Workspace.CurrentCamera.Focus.p).Unit * -999
		)

		local Part, EndPoint = Workspace:FindPartOnRayWithIgnoreList(Ray, {Players.LocalPlayer.Character})
		if not Part then
			local SunPositionGlobal = GetSunPositionOnScreenRelativeToCamera(Workspace.CurrentCamera, 10).p
			local SunIsOnScreen, SunPositionOnScreen, Angle = qGUI.WorldToScreen(SunPositionGlobal, Mouse, Workspace.CurrentCamera)
			Render(SunPositionOnScreen, Mouse, SunIsOnScreen)
		else
			--print("[LensFlare] - Hit "..Part.Name.." no render")
			Render(nil, Mouse, false)
		end
	end
	LensFlare.Step = Step
end)
lib.MakeLensFlare = MakeLensFlare
lib.makeLensFlare = MakeLensFlare

return lib