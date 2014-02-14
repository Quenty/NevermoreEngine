local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local qGUI              = LoadCustomLibrary("qGUI")

-- InventoryOptionMaker.lua
-- @author Quenty


--[[ -- Change Log
February 13th, 2014
- Fixed glitch / problem with icon variables being overwritten

February 7th, 2014
- Removed BoxInventoryRender dependency
- Added change log

February 3rd, 2014
- Updated to work with NevermoreEngine
--]]
qSystems:Import(getfenv(0));

local lib = {}

local function MakeIconOptionBase(Name, Color, IconURL)
	-- Generates the basis for a button, to be modified later. Handles some Gui stuff like animations.

	local Configuration = {
		Height              = 40;
		Color               = Color or Color3.new(0.8, 0.8, 0.8);
		ZIndex              = 3;
		DefaultTransparency = 0.7; -- Normal backing transparency
		EnterTransparency   = 0.6; -- Transparency when a players mouse enters.
	}
	
	local XSpacing = 10;

	local Button = Make 'ImageButton' {
		Archivable             = false;
		AutoButtonColor        = false;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = Configuration.DefaultTransparency;
		BorderSizePixel        = 0;
		ClipsDescendants       = false;
		Name                   = Name.."Button";
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, 0, 0, Configuration.Height);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex + 1;
	}

	local Icon

	-- Generate icon if available.
	if IconURL then
		Icon = Make 'Frame' {
			Archivable             = false;
			BackgroundColor3       = Configuration.Color;
			BackgroundTransparency = 1;
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Name                   = "IconContainer";
			Parent                 = Button;
			Size                   = UDim2.new(0, Configuration.Height, 1, 0);
			Visible                = true;
			ZIndex                 = Button.ZIndex;
			Make 'ImageLabel' {
				Archivable             = false;
				BackgroundTransparency = 1;
				BorderSizePixel        = 0;
				ZIndex                 = Button.ZIndex;
				Size                   = UDim2.new(1, 0, 1, 0);
				Visible                = true;
				Name                   = "Icon";
				Image                  = IconURL;
			}
		}
		XSpacing = XSpacing + Configuration.Height;
	end

	local TextLabel = Make 'TextLabel' {
		Archivable             = false;
		BackgroundTransparency = 1;
		Font                   = "Arial";
		FontSize               = "Size14";
		Parent                 = Button;
		Position               = UDim2.new(0, XSpacing, 0, 0);
		Size                   = UDim2.new(1, -XSpacing, 1, 0);
		Text                   = Name;
		TextColor3             = Color3.new(1, 1, 1);
		TextStrokeTransparency = 1;
		TextTransparency       = 0;
		TextXAlignment         = "Left";
		TextYAlignment         = "Center";
		Visible                = true;
		ZIndex                 = Button.ZIndex;
	}

	Button.MouseEnter:connect(function()
		if Icon then
			Icon.BackgroundTransparency = 0;
		end
		Button.BackgroundTransparency = Configuration.EnterTransparency;
	end)

	Button.MouseLeave:connect(function()
		if Icon then
			Icon.BackgroundTransparency = 1;
		end
		Button.BackgroundTransparency = Configuration.DefaultTransparency;
	end)

	local Option = {}
	Option.Gui           = Button
	Option.RenderHeightY = Configuration.Height;
	Option.Shown         = true;
	Option.Update        = function(self, Box2DInterface)
		local Selection = Box2DInterface.BoxSelection.GetSelection()
		self.Shown      = #Selected >= 1
	end
	return Option
end
lib.MakeIconOptionBase = MakeIconOptionBase
lib.makeIconOptionBase = MakeIconOptionBase

return lib