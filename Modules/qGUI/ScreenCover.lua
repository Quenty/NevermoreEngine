local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems = LoadCustomLibrary("qSystems")
local EnumInterpreter = LoadCustomLibrary("EnumInterpreter")
local qMath = LoadCustomLibrary("qMath");

local lib               = {}

-- ScreenCover.lua
-- @author Quenty
-- Last Modified November 17th, 2014

local Round  = qSystems.Round
local Modify = qSystems.Modify


lib.STYLES = {}
lib.TYPES = {
	"TransitionOut";
	"TransitionIn";
}

local function MakeCover(Properties)
	-- Generates a cover frame that is basically standard. :D

	Properties = Properties or {}
	local Frame = Instance.new("Frame")
	Frame.Size                   = UDim2.new(1, 0, 1, 2)
	Frame.Position               = UDim2.new(0, 0, 0, -2)
	Frame.BackgroundColor3       = Color3.new(0, 0, 0)
	Frame.BackgroundTransparency = 1
	Frame.Visible                = false
	Frame.Name                   = "ScreenCover"
	Frame.ZIndex                 = 10
	Frame.BorderSizePixel        = 0
	
	return Modify(Frame, Properties)
end

lib.MakeCover = MakeCover

local function SmoothInOut(Percent, Factor)
	if Percent < 0.5 then
		return ((Percent*2)^Factor)/2
	else
		return (-((-(Percent*2) + 2)^Factor))/2 + 1
	end
end

local function SmoothIn(Percent, Factor)
	return Percent^Factor
end

local function SmoothOut(Percent, Factor)
	return Percent^(1/Factor)
end

local Offset = 10
local function CenterCircleGui(BaseCover, TopFrame, BottomFrame, LeftFrame, RightFrame, CircleGui) 

	CircleGui.Position = UDim2.new(0.5, -CircleGui.Size.X.Offset/2, 0.5, -CircleGui.Size.Y.Offset/2);

	--- Center's the circle gui and resizes the surrounding labels
	TopFrame.Size = UDim2.new(1, Offset, 0, (BaseCover.AbsoluteSize.Y - CircleGui.Size.Y.Offset)/2 + Offset/2)
	TopFrame.Position = UDim2.new(0, -Offset/2, 0.5, -(CircleGui.Size.Y.Offset/2 + TopFrame.Size.Y.Offset))

	BottomFrame.Size = TopFrame.Size; --UDim2.new(1, Offset, 0, (BaseCover.AbsoluteSize.Y - CircleGui.Size.Y.Offset)/2 + Offset/2)
	BottomFrame.Position = UDim2.new(0, -Offset/2, 0.5, (CircleGui.Size.Y.Offset/2))

	LeftFrame.Size = UDim2.new(0, (BaseCover.AbsoluteSize.X - CircleGui.Size.X.Offset)/2 + Offset/2, 1, Offset)
	LeftFrame.Position = UDim2.new(0.5, -(CircleGui.Size.X.Offset/2 + LeftFrame.Size.X.Offset), 0, -Offset/2)
	-- LeftFrame.Position = UDim2.new(0, -Offset, 0.5, -CircleGui.Size.Y.Offset/2 - Offset/2)

	RightFrame.Size = LeftFrame.Size-- UDim2.new(0, (BaseCover.AbsoluteSize.X - CircleGui.Size.X.Offset)/2 + Offset/2, 1, Offset)
	RightFrame.Position = UDim2.new(0.5, (CircleGui.Size.X.Offset/2), 0, -Offset/2)
	-- RightFrame.Size = UDim2.new(0.5, -CircleGui.Size.X.Offset/2 + Offset, 0, CircleGui.Size.Y.Offset  + Offset)
	-- RightFrame.Position = UDim2.new(1, -CircleGui.Size.X.Offset, 0.5, -CircleGui.Size.Y.Offset/2 - Offset/2)
end

local function GenerateCircleGui(BaseCover, CircleSize, ZIndex)
	ZIndex = ZIndex or 1;

	local CircleGui = Instance.new("ImageLabel")
	CircleGui.Archivable  = false
	CircleGui.BorderSizePixel = 0
	CircleGui.BackgroundTransparency = 1
	CircleGui.Image = "http://www.roblox.com/asset/?id=148523274"
	CircleGui.Size = UDim2.new(0, CircleSize, 0, CircleSize)
	CircleGui.ZIndex = ZIndex
	CircleGui.Parent = BaseCover

	-- Stretch accross the whole top.
	local TopFrame = Instance.new("Frame")
	TopFrame.Archivable = false
	TopFrame.BorderSizePixel = 0
	TopFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	TopFrame.Name = "TopFrame"
	TopFrame.ZIndex = ZIndex
	TopFrame.Parent = BaseCover

	-- Stretch accross the whole bottom.
	local BottomFrame = Instance.new("Frame")
	BottomFrame.Archivable = false
	BottomFrame.BorderSizePixel = 0
	BottomFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	BottomFrame.Name = "BottomFrame"
	BottomFrame.ZIndex = ZIndex
	BottomFrame.Parent = BaseCover

	local LeftFrame = Instance.new("Frame")
	LeftFrame.Archivable = false
	LeftFrame.BorderSizePixel = 0
	LeftFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	LeftFrame.Name = "LeftFrame"
	LeftFrame.ZIndex = ZIndex
	LeftFrame.Parent = BaseCover

	local RightFrame = Instance.new("Frame")
	RightFrame.Archivable = false
	RightFrame.BorderSizePixel = 0
	RightFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	RightFrame.Name = "RightFrame"
	RightFrame.ZIndex = ZIndex
	RightFrame.Parent = BaseCover

	return CircleGui, TopFrame, BottomFrame, LeftFrame, RightFrame
end

local StyleFunctions = {
	Fade = {
		TransitionOut = function(Time, BaseCover) -- Basically, it'll hand the function a "BaseCover", which presumadly covers the whole screen.  It'll also hand it a
		-- time to animate. From there on, it's expected that the function will execute in the time given, and end up with the BaseCover covering the whole screen...
		-- with no extra objects in it. :)

		-- Since this is 'TransitionOut', it'll start at 0, and go to 1 transparency...

			local StartTime = time();
			local FinishTime = Time + StartTime
			while FinishTime > time() do
				BaseCover.BackgroundTransparency =  (time() - StartTime) / Time
				wait(0.03);
			end
			BaseCover.BackgroundTransparency = 1;
			return true;
		end;
		TransitionIn = function(Time, BaseCover)
			local StartTime = time();
			local FinishTime = Time + StartTime
			while FinishTime > time() do
				BaseCover.BackgroundTransparency =  1 - ((time() - StartTime) / Time)
				wait(0.03);
			end
			BaseCover.BackgroundTransparency = 0;
			return true;
		end;
	};
	SlideDown = {
		-- Optimal with fast animation times.

		TransitionIn = function(Time, BaseCover, AnimationStyles)
			local NewCover = BaseCover:Clone()
			NewCover.Parent = BaseCover
			NewCover.Size = UDim2.new(1, 0, 1, 0)
			NewCover.Position = UDim2.new(0, 0, -1, 0)
			NewCover.BackgroundTransparency = 0;
			NewCover:TweenPosition(UDim2.new(0, 0, 0, 0), "In", AnimationStyles.EasingStyle or ("Quad"), Time, true)
			BaseCover.BackgroundTransparency = 1
			wait(Time)
			NewCover:Destroy()
			BaseCover.BackgroundTransparency = 0
			return true;
		end;
		TransitionOut = function(Time, BaseCover, AnimationStyles)
			local NewCover = BaseCover:Clone()
			NewCover.Parent = BaseCover
			NewCover.Size = UDim2.new(1, 0, 1, 0)
			NewCover.Position = UDim2.new(0, 0, 0, 0)
			NewCover:TweenPosition(UDim2.new(0, 0, 1, 0), "Out", AnimationStyles.EasingStyle or ("Quad"), Time, true)
			BaseCover.BackgroundTransparency = 1
			wait(Time)
			NewCover:Destroy()
			return true;
		end;
	};
	SlideUp = {
		-- Optimal with fast animation times.

		TransitionIn = function(Time, BaseCover, AnimationStyles)
			local NewCover                   = BaseCover:Clone()
			NewCover.Parent                  = BaseCover
			NewCover.Size                    = UDim2.new(1, 0, 1, 0)
			NewCover.Position                = UDim2.new(0, 0, 1, 0)
			NewCover.BackgroundTransparency  = 0;

			NewCover:TweenPosition(UDim2.new(0, 0, 0, 0), "In", AnimationStyles.EasingStyle or ("Quad"), Time, true)
			
			BaseCover.BackgroundTransparency = 1
			wait(Time)
			NewCover:Destroy()
			BaseCover.BackgroundTransparency = 0
			return true;
		end;
		TransitionOut = function(Time, BaseCover, AnimationStyles)
			local NewCover = BaseCover:Clone()
			NewCover.Parent = BaseCover
			NewCover.Size = UDim2.new(1, 0, 1, 0)
			NewCover.Position = UDim2.new(0, 0, 0, 0)
			NewCover:TweenPosition(UDim2.new(0, 0, -1, 0), "Out", AnimationStyles.EasingStyle or ("Quad"), Time, true)
			BaseCover.BackgroundTransparency = 1
			wait(Time)
			NewCover:Destroy()
			return true;
		end;
	};
	DiagonalSquares = {
		TransitionIn = function(Time, BaseCover, AnimationStyles)
			-- SquareSize must be divisible by 2. 
			-- If the squareSize is too small, you can get wait() lag (I think).

			SquareSize                       = qMath.RoundUp(AnimationStyles.SquareSize or 76, 2);
			local NewCover                   = BaseCover:Clone()
			NewCover.Name                    = "Square"
			NewCover.Size                    = UDim2.new(0, 0, 0, 0);
			NewCover.BackgroundTransparency  = 0;
			BaseCover.BackgroundTransparency = 1;
			
			
			local MaxSize                    = qMath.RoundUp(math.max(BaseCover.AbsoluteSize.X, BaseCover.AbsoluteSize.Y) * 1.6, SquareSize) + SquareSize
			local Squares                    = {}
			local ValX                       = 0;
			local ValY                       = 0;
			local WaitEach                   = (Time/2)/(MaxSize/SquareSize)

			while ValY <= MaxSize do
				ValX = 0;
				while ValX <= ValY do
					local Square = NewCover:Clone()
					Square.Archivable = false;
					Square.Position = UDim2.new(0, ValX + (SquareSize/2), 0, ValY - (ValX) + (SquareSize/2));
					Square.Parent = BaseCover;
					local NewPosition = Square.Position - UDim2.new(0, SquareSize/2, 0, SquareSize/2)
					table.insert(Squares, Square)

					delay(WaitEach * (ValY/SquareSize), function()
						Square:TweenSizeAndPosition(UDim2.new(0, SquareSize, 0, SquareSize), NewPosition, "In", "Quad", Time/2, true)
					end)
					ValX = ValX + SquareSize
				end
				ValY = ValY + SquareSize
			end
			wait(Time)

			BaseCover.BackgroundTransparency = 0;
			for _, Square in pairs(Squares) do
				Square:Destroy()
			end
			return true;
		end;
		TransitionOut = function(Time, BaseCover, AnimationStyles)
			SquareSize                      = qMath.RoundUp(AnimationStyles.SquareSize or 76, 2);
			
			local NewCover                  = BaseCover:Clone()
			NewCover.Name                   = "Square"
			NewCover.Size                   = UDim2.new(0, SquareSize, 0, SquareSize);
			
			local MaxSize                   = qMath.RoundUp(math.max(BaseCover.AbsoluteSize.X, BaseCover.AbsoluteSize.Y) * 1.6, SquareSize) + SquareSize
			local Squares                   = {}
			local ValX                      = 0;
			local ValY                      = MaxSize;
			local WaitEach                  = (Time/2)/(MaxSize/SquareSize)

			while ValY >= 0 do
				ValX = 0;
				while ValX <= ValY do
					local Square = NewCover:Clone()
					Square.Archivable = false;
					Square.Parent = BaseCover;
					Square.Position = UDim2.new(0, ValX, 0, ValY - ValX);
					local NewPosition = Square.Position + UDim2.new(0, (SquareSize/2), 0, (SquareSize/2));
					table.insert(Squares, Square)

					delay(WaitEach * (ValY/SquareSize), function() 
						Square:TweenSizeAndPosition(UDim2.new(0, 0, 0, 0), NewPosition, "Out", "Quad", Time/2, true)
					end)
					ValX = ValX + SquareSize
				end
				ValY = ValY - SquareSize
			end

			BaseCover.BackgroundTransparency = 1;
			wait(Time)
			for _, Square in pairs(Squares) do
				Square:Destroy()
			end
			return true;
		end;
	};
	StraightSquare = {
		TransitionIn = function(Time, BaseCover, AnimationStyles)
			-- SquareSize must be divisible by 2. 
			-- If the squareSize is too small, you can get wait() lag (I think).

			SquareSize                       = qMath.RoundUp(AnimationStyles.SquareSize or 76, 2);
			local NewCover                   = BaseCover:Clone()
			NewCover.Name                    = "Square"
			NewCover.Size                    = UDim2.new(0, 0, 0, 0);
			NewCover.BackgroundTransparency  = 0;
			BaseCover.BackgroundTransparency = 1;
			
			
			local MaxSize                    = qMath.RoundUp(math.max(BaseCover.AbsoluteSize.X, BaseCover.AbsoluteSize.Y) * 1.6, SquareSize) + SquareSize
			local Squares                    = {}
			local ValX                       = 0;
			local ValY                       = 0;
			local WaitEach                   = (Time/2)/(MaxSize/SquareSize)

			while ValY <= MaxSize do
				ValX = 0;
				while ValX <= MaxSize do
					local Square = NewCover:Clone()
					Square.Archivable = false;
					Square.Position = UDim2.new(0, ValX, 0, ValY);
					Square.Parent = BaseCover;
					local NewPosition = Square.Position - UDim2.new(0, SquareSize/2, 0, SquareSize/2)
					table.insert(Squares, Square)

					delay(WaitEach * (ValX/SquareSize), function() 
						Square:TweenSizeAndPosition(UDim2.new(0, SquareSize, 0, SquareSize), NewPosition, "In", "Quad", Time/2, true)
					end)
					ValX = ValX + SquareSize
				end
				ValY = ValY + SquareSize
			end
			wait(Time)

			BaseCover.BackgroundTransparency = 0;
			for _, Square in pairs(Squares) do
				Square:Destroy();
			end
			return true;
		end;
		TransitionOut = function(Time, BaseCover, AnimationStyles)
			print("No out")
		end;
	};
	Circle = {
		TransitionIn = function(Time, BaseCover, AnimationStyles)
			local CircleSize = math.max(BaseCover.AbsoluteSize.X, BaseCover.AbsoluteSize.Y)*math.sqrt(2) -- Presuming image takes up whole area.
			BaseCover.BackgroundTransparency = 1;

			local CircleGui, TopFrame, BottomFrame, LeftFrame, RightFrame = GenerateCircleGui(BaseCover, CircleSize, BaseCover.ZIndex)

			local function ResizeCircle(Radius)
				Radius = Round(Radius, 2)
				CircleGui.Size = UDim2.new(0, Radius, 0, Radius)
				CenterCircleGui(BaseCover, TopFrame, BottomFrame, LeftFrame, RightFrame, CircleGui)
			end
			
			local StartTime = time();
			local FinishTime = Time + StartTime
			while FinishTime > time() do
				local Percent = (1 - ((time() - StartTime) / Time)) * CircleSize
				ResizeCircle(Percent)
				RunService.RenderStepped:wait(0)
				---wait(0.03);
			end
			ResizeCircle(0)

			BaseCover.BackgroundTransparency = 0;

			CircleGui:Destroy()
			TopFrame:Destroy()
			BottomFrame:Destroy()
			LeftFrame:Destroy()
			RightFrame:Destroy()

			return true;
		end;
		TransitionOut = function(Time, BaseCover, AnimationStyles)
			local CircleSize = math.max(BaseCover.AbsoluteSize.X, BaseCover.AbsoluteSize.Y)*math.sqrt(2) -- Presuming image takes up whole area.
			BaseCover.BackgroundTransparency = 1;

			local CircleGui, TopFrame, BottomFrame, LeftFrame, RightFrame = GenerateCircleGui(BaseCover, 0, BaseCover.ZIndex)

			local function ResizeCircle(Radius)
				Radius = Round(Radius, 2)
				CircleGui.Size = UDim2.new(0, Radius, 0, Radius)
				CenterCircleGui(BaseCover, TopFrame, BottomFrame, LeftFrame, RightFrame, CircleGui)
			end
			
			local StartTime = time();
			local FinishTime = Time + StartTime
			while FinishTime > time() do
				local Percent = ((time() - StartTime) / Time) * CircleSize
				ResizeCircle(Percent)
				RunService.RenderStepped:wait(0)
				-- wait(0.03);
			end
			ResizeCircle(CircleSize)

			CircleGui:Destroy()
			TopFrame:Destroy()
			BottomFrame:Destroy()
			LeftFrame:Destroy()
			RightFrame:Destroy()

			return true;
		end;
	};
}

for StyleName, StyleData in pairs(StyleFunctions) do
	lib.STYLES[#lib.STYLES+1] = StyleName;
	StyleData.EnumID = #lib.STYLES
end

--[[
StyleFunctions.Squares.TransitionIn()

--]]

--[[

AnimationStyles = {
	AnimationStyle = STYLES;
	Type = TYPES;
	AnimationTime = NUMBER;
}
--]]

local function MakeScreenCover(BaseCover, AnimationStyles)
	local AnimationTime = AnimationStyles.AnimationTime or 1;
	local AnimationStyle = EnumInterpreter.GetEnumName(lib.STYLES, (AnimationStyles.AnimationStyle or "Fade")) -- Guarantee exact results (Lowercase, uppercase, etc. )
	local Type = EnumInterpreter.GetEnumName(lib.TYPES, (AnimationStyles.Type or "TransitionOut"))

	--print("[ScreenCover] - running animation: Type: "..Type.."; Style: "..AnimationStyle.."; Time: "..AnimationTime)

	BaseCover.Visible = true;
	BaseCover.Transparency = (Type == "TransitionOut" and 0 or 1);

	--local timeStart = tick();

	StyleFunctions[AnimationStyle][Type](AnimationTime, BaseCover, AnimationStyles)

	--print("[ScreenCover] - Time elapsed: "..tick() - timeStart);
	return BaseCover;
end

lib.MakeScreenCover = MakeScreenCover
lib.makeScreenCover = MakeScreenCover

return lib