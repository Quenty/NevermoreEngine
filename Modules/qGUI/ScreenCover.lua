local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local EnumInterpreter   = LoadCustomLibrary("EnumInterpreter")
local qMath             = LoadCustomLibrary("qMath");

local lib    = {}

-- ScreenCover.lua
-- @author Quenty
-- Last Modified February 3rd, 2014

qSystems:import(getfenv(0));

lib.STYLES = {}
lib.TYPES = {
	"Show";
	"Hide";
}

local function MakeCover(Properties)
	-- Generates a cover frame that is basically standard. :D

	Properties = Properties or {}

	return Modify((Make 'Frame' {
			--Parent = ScreenGui;
			Size = UDim2.new(1, 0, 1, 2);
			Position = UDim2.new(0, 0, 0, -2); -- Fix ROBLOX's glitches...
			BackgroundColor3 = Color3.new(0, 0, 0);
			BackgroundTransparency = 1;
			Visible = false;
			Name = "ScreenCover";
			ZIndex = 10;
			BorderSizePixel = 0;
		}), Properties)
end

lib.MakeCover = MakeCover
lib.makeCover = MakeCover

local StyleFunctions = {
	Fade = {
		Show = function(Time, BaseCover) -- Basically, it'll hand the function a "BaseCover", which presumadly covers the whole screen.  It'll also hand it a
		-- time to animate. From there on, it's expected that the function will execute in the time given, and end up with the BaseCover covering the whole screen...
		-- with no extra objects in it. :)

		-- Since this is 'Show', it'll start at 0, and go to 1 transparency...

			local StartTime = time();
			local FinishTime = Time + StartTime
			while FinishTime > time() do
				BaseCover.BackgroundTransparency =  (time() - StartTime) / Time
				wait(0.03);
			end
			BaseCover.BackgroundTransparency = 1;
			return true;
		end;
		Hide = function(Time, BaseCover)
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

		Hide = function(Time, BaseCover, AnimationStyles)
			local NewCover = BaseCover:Clone()
			NewCover.Parent = BaseCover
			NewCover.Size = UDim2.new(1, 0, 1, 0)
			NewCover.Position = UDim2.new(0, 0, -1, 0)
			NewCover.BackgroundTransparency = 0;
			NewCover:TweenPosition(UDim2.new(0, 0, 0, 0), "In", AnimationStyles.EasingStyle or ("Sine"), Time, true)
			BaseCover.BackgroundTransparency = 1
			wait(Time)
			NewCover:Destroy()
			BaseCover.BackgroundTransparency = 0
			return true;
		end;
		Show = function(Time, BaseCover, AnimationStyles)
			local NewCover = BaseCover:Clone()
			NewCover.Parent = BaseCover
			NewCover.Size = UDim2.new(1, 0, 1, 0)
			NewCover.Position = UDim2.new(0, 0, 0, 0)
			NewCover:TweenPosition(UDim2.new(0, 0, 1, 0), "Out", AnimationStyles.EasingStyle or ("Sine"), Time, true)
			BaseCover.BackgroundTransparency = 1
			wait(Time)
			NewCover:Destroy()
			return true;
		end;
	};
	SlideUp = {
		-- Optimal with fast animation times.

		Hide = function(Time, BaseCover, AnimationStyles)
			local NewCover = BaseCover:Clone()
			NewCover.Parent = BaseCover
			NewCover.Size = UDim2.new(1, 0, 1, 0)
			NewCover.Position = UDim2.new(0, 0, 1, 0)
			NewCover.BackgroundTransparency = 0;
			NewCover:TweenPosition(UDim2.new(0, 0, 0, 0), "In", AnimationStyles.EasingStyle or ("Sine"), Time, true)
			BaseCover.BackgroundTransparency = 1
			wait(Time)
			NewCover:Destroy()
			BaseCover.BackgroundTransparency = 0
			return true;
		end;
		Show = function(Time, BaseCover, AnimationStyles)
			local NewCover = BaseCover:Clone()
			NewCover.Parent = BaseCover
			NewCover.Size = UDim2.new(1, 0, 1, 0)
			NewCover.Position = UDim2.new(0, 0, 0, 0)
			NewCover:TweenPosition(UDim2.new(0, 0, -1, 0), "Out", AnimationStyles.EasingStyle or ("Sine"), Time, true)
			BaseCover.BackgroundTransparency = 1
			wait(Time)
			NewCover:Destroy()
			return true;
		end;
	};
	Squares = {
		Hide = function(Time, BaseCover, AnimationStyles)
			-- SquareSize must be divisible by 2. 
			-- If the squareSize is too small, you can get wait() lag (I think).

			SquareSize                       = qMath.roundUp(AnimationStyles.SquareSize or 76, 2);
			local NewCover                   = BaseCover:Clone()
			NewCover.Name                    = "Square"
			NewCover.Size                    = UDim2.new(0, 0, 0, 0);
			NewCover.BackgroundTransparency  = 0;
			BaseCover.BackgroundTransparency = 1;
			
			
			local MaxSize                    = qMath.roundUp(math.max(BaseCover.AbsoluteSize.X, BaseCover.AbsoluteSize.Y) * 1.6, SquareSize) + SquareSize
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
						Square:TweenSizeAndPosition(UDim2.new(0, SquareSize, 0, SquareSize), NewPosition, "Out", "Sine", Time/2, true)
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
		Show = function(Time, BaseCover, AnimationStyles)
			SquareSize                      = qMath.roundUp(AnimationStyles.SquareSize or 76, 2);
			
			local NewCover                  = BaseCover:Clone()
			NewCover.Name                   = "Square"
			NewCover.Size                   = UDim2.new(0, SquareSize, 0, SquareSize);
			
			local MaxSize                   = qMath.roundUp(math.max(BaseCover.AbsoluteSize.X, BaseCover.AbsoluteSize.Y) * 1.6, SquareSize) + SquareSize
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
						Square:TweenSizeAndPosition(UDim2.new(0, 0, 0, 0), NewPosition, "Out", "Sine", Time/2, true)
					end)
					ValX = ValX + SquareSize
				end
				ValY = ValY - SquareSize
			end

			BaseCover.BackgroundTransparency = 1;
			wait(Time)
			for _, Square in pairs(Squares) do
				Square:Destroy();
			end
			return true;
		end;
	};
}

for StyleName, StyleData in pairs(StyleFunctions) do
	lib.STYLES[#lib.STYLES+1] = StyleName;
	StyleData.EnumID = #lib.STYLES
end

--[[
StyleFunctions.Squares.Hide()

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
	local Type = EnumInterpreter.GetEnumName(lib.TYPES, (AnimationStyles.Type or "Show"))

	--print("[ScreenCover] - running animation: Type: "..Type.."; Style: "..AnimationStyle.."; Time: "..AnimationTime)

	BaseCover.Visible = true;
	BaseCover.Transparency = (Type == "Show" and 0 or 1);

	--local timeStart = tick();

	StyleFunctions[AnimationStyle][Type](AnimationTime, BaseCover, AnimationStyles)

	--print("[ScreenCover] - Time elapsed: "..tick() - timeStart);
	return BaseCover;
end

lib.MakeScreenCover = MakeScreenCover
lib.makeScreenCover = MakeScreenCover

return lib