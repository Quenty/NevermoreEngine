while not _G.NevermoreEngine do wait(0) end

local Players              = Game:GetService('Players')
local StarterPack          = Game:GetService('StarterPack')
local StarterGui           = Game:GetService('StarterGui')
local Lighting             = Game:GetService('Lighting')
local Debris               = Game:GetService('Debris')
local Teams                = Game:GetService('Teams')
local BadgeService         = Game:GetService('BadgeService')
local InsertService        = Game:GetService('InsertService')
local Terrain              = Workspace.Terrain

local NevermoreEngine      = _G.NevermoreEngine
local LoadCustomLibrary    = NevermoreEngine.LoadLibrary;

local qSystems             = LoadCustomLibrary('qSystems')
local ParagraphConstructor = LoadCustomLibrary('ParagraphConstructor')
local MenuSystem           = LoadCustomLibrary('MenuSystem')
local qGUI                 = LoadCustomLibrary('qGUI')
local qString              = LoadCustomLibrary('qString')
local ScrollBar            = LoadCustomLibrary('ScrollBar')

qSystems:Import(getfenv(0));

--[[

This system draws up documentation and instructions based upon markdown, and allows
the menu system to interact with it.  To be used specifically with the menu system.

--]]

local lib = {}

local MakeDocumentationSystem = Class 'DocumentationSystem' (function(DocumentationSystem, Menu, ScreenGui, Format)
	-- Should not be used while another system designed for MenuSystem is being used. That is, don't try to pull up instructions
	-- while customization is open or something.

	Format = Format or {}
	Format.Name = Format.Name or "Documentation" -- What the menu displays as. 
	Format.SizeX = Format.SizeX or 400;
	Format.OffsetX = Format.OffsetX or 260
	Format.OffsetY = Format.OffsetY or 10 -- When scrolling, space between the top of the screen and the text's start.
	Format.ExtraYOffsetBetween = Format.ExtraYOffsetBetween or 400 -- for safety's sake... What if they resize the screen? 
	Format.CharacterLimit = 15;
	Format.FadeBackgroundTo = 0.7;

	local Instructions = {}
	local DocumentationMenu = MenuSystem.MakeListMenuLevel(Format.Name)
	local LastInstructionPosition = 0; -- Keep track of Y axis...
	local ShowMenuVisible = false
	local ShowMenuLevel = 0

	local DocumentationFrame = Make 'Frame' {
		BackgroundColor3       = qGUI.NewColor3(0, 0, 0);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "qDocumentationSystem";
		Parent                 = ScreenGui;
		Size                   = UDim2.new(1, 0, 1, 0);
		Visible                = true;
		ZIndex                 = 1;
	}
	local ShowInstructions, HideInstructions
	local FirstInstructonTitle

	local Container = Make 'ImageButton' {
		Name = "Container";
		Parent = DocumentationFrame;
		Size = UDim2.new(0, Format.SizeX, 1, 0);
		Position = UDim2.new(0, Format.OffsetX, 1, 10);
		Visible = true;
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
	};

	--local Scroller = ScrollBar.MakeScroller(DocumentationFrame, Container, ScreenGui, 'Y')
	--Scroller.CanDrag = true

	Menu.MenuLevelChange:connect(function(NewLevel)
		if NewLevel < ShowMenuLevel then
			--print("[DocumentationSystem] - DocumentationMenu is hiding / being disconnected")
			ShowMenuVisible = false
			HideInstructions()
		end
	end)

	local function GetFirstInstruction()
		-- Return's the first instruction it can find. 
		if FirstInstructonTitle and Instructions[FirstInstructonTitle] then
			return Instructions[FirstInstructonTitle]
		else
			print("[DocumentationSystem] - Warning, FirstInstructonTitle failed")
			for _, Item in pairs(Instructions) do
				return Item
			end
			error("[DocumentationSystem] - No instructions have been added to the MenuDocumentationSystem")
		end
	end

	local function ShowMenu()
		if not ShowMenuVisible then
			--print("[DocumentationSystem] - DocumentationMenu being shown") 
			ShowMenuLevel = Menu.CurrentLevel + 1
			Menu:AddMenuLayer(DocumentationMenu)
			ShowMenuVisible = true

			local Instruction = GetFirstInstruction()
			if Instruction then
				ShowInstructions(Instruction.Title)
			end

		else
			error("[DocumentationSystem] - DocumentationMenu is already visible") 
		end
	end
	DocumentationSystem.ShowMenu = ShowMenu

	function ShowInstructions(InstructionTitle, Animation)
		if not ShowMenuVisible then 
			Menu:AddMenuLayer(DocumentationMenu)
		end
		Animation = Animation or "slide"
		Animation = Animation:lower()
		local Instruction = Instructions[InstructionTitle]
		assert(Instructions[InstructionTitle], "Instruction "..tostring(InstructionTitle).." equals "..tostring(Instructions[InstructionTitle]).."'")
		local InstructionPosition = UDim2.new(0, Format.OffsetX, 0, -Instruction.Position + Format.OffsetY)

		if DocumentationFrame.BackgroundTransparency ~= Format.FadeBackgroundTo then
			if Animation ~= "none" then
				qGUI.TweenTransparency(DocumentationFrame, {
					BackgroundTransparency = Format.FadeBackgroundTo
				}, 0.5, true)
				CallOnChildren(Container, function(Child)
					if Child:IsA("TextLabel") then
						if Child:IsDescendantOf(Instructions.Gui) then
							if Child.TextTransparency ~= 0 then
								qGUI.TweenTransparency(Child, {TextTransparency = 0}, 0.5, true)
							end
						else
							if Child.TextTransparency ~= 1 then
								qGUI.TweenTransparency(Child, {TextTransparency = 1}, 0.5, true)
							end
						end
					end
				end)
			else
				DocumentationFrame.BackgroundTransparency = Format.FadeBackgroundTo
				CallOnChildren(Container, function(Child)
					if Child:IsA("TextLabel") then
						if Child:IsDescendantOf(Instructions.Gui) then
							Child.TextTransparency = 0
						else
							Child.TextTransparency = 1
						end
					end
				end)
			end
		end
		--print('-(Instruction.Position+Instruction.Size-ScreenGui.AbsoluteSize.Y), Instruction.Position = '..-(Instruction.Position+Instruction.Size-ScreenGui.AbsoluteSize.Y)..", "..-Instruction.Position)
		--Scroller.KineticModel:SetRange(math.min(-(Instruction.Position-ScreenGui.AbsoluteSize.Y), -(Instruction.Position+Instruction.Size-ScreenGui.AbsoluteSize.Y)), 0)
		--Scroller.CanDrag = true
		if Animation == "slide" then
			--Scroller.KineticModel:ScrollTo(-Instruction.Position + Format.OffsetY)
			Container:TweenPosition(InstructionPosition, "Out", "Sine", 0.5, true)
		elseif Animation == "none" then
			Container.Position = InstructionPosition;
		else
			error("[DocumentationSystem] - No animation specified", 2)
		end
	end
	DocumentationSystem.ShowInstructions = ShowInstructions

	function HideInstructions(Animation)
		--Scroller.CanDrag = false
		Animation = Animation or "slide"
		Animation = Animation:lower()

		if DocumentationFrame.BackgroundTransparency ~= 1 then
			if Animation ~= "none" then
				qGUI.TweenTransparency(DocumentationFrame, {BackgroundTransparency = 1;}, 0.5, true)
				CallOnChildren(Container, function(Child)
					if Child:IsA("TextLabel") then
						if Child.TextTransparency ~= 1 then
							qGUI.TweenTransparency(Child, {TextTransparency = 1;}, 0.5, true)
						end
					end
				end)
			else
				DocumentationFrame.BackgroundTransparency = 1
				CallOnChildren(Container, function(Child)
					if Child:IsA("TextLabel") then
						Child.TextTransparency = 1
					end
				end)
			end
		end

		local InstructionPosition = UDim2.new(0, Format.OffsetX, 1, 50);

		if Animation == "slide" then
			Container:TweenPosition(InstructionPosition, "In", "Sine", 0.5, true)
		elseif Animation == "none" then
			Container.Position = InstructionPosition;
		else
			error("[DocumentationSystem] - No animation specified", 2)
		end
	end
	DocumentationSystem.HideInstructions = HideInstructions

	local function AddInstruction(InstructionTitle, Text)
		-- Adds a button to the documentation menu, and adds instructions...

		local NewInstruction = {}
		NewInstruction.Text = Text
		NewInstruction.Title = InstructionTitle
		local Button = MenuSystem.MakeMenuButton(qString.DumbElipseLimit(InstructionTitle, Format.CharacterLimit))
		DocumentationMenu:AddRawButton(Button)
		local Frame = Make 'Frame' {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Name                   = InstructionTitle.."Container";
			Parent                 = Container;
			Size                   = UDim2.new(1, 0, 0, 0);
			Visible                = true;
		}

		NewInstruction.Gui = Frame
		local _, HeightY = ParagraphConstructor.ConstructBlock(Text, Frame, ScreenGui, {})
		NewInstruction.Position = LastInstructionPosition;
		Frame.Position = UDim2.new(0, 0, 0, LastInstructionPosition)
		NewInstruction.Size = HeightY
		LastInstructionPosition = NewInstruction.Position + HeightY + ScreenGui.AbsoluteSize.Y + Format.ExtraYOffsetBetween;
		Container.Size = UDim2.new(0, Format.SizeX, 0, LastInstructionPosition)
		Instructions[InstructionTitle] = NewInstruction

		if not FirstInstructonTitle then
			FirstInstructonTitle = InstructionTitle
		end

		Button.OnClick:connect(function()
			ShowInstructions(InstructionTitle)
		end)
	end
	DocumentationSystem.AddInstruction = AddInstruction

	
end)
lib.MakeDocumentationSystem = MakeDocumentationSystem
lib.makeDocumentationSystem = MakeDocumentationSystem

NevermoreEngine.RegisterLibrary('MenuDocumentationSystem', lib)