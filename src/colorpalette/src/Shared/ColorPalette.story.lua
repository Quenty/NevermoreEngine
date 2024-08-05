--[[
	@class ColorPalette.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local Blend = require("Blend")
local ColorPickerStoryUtils = require("ColorPickerStoryUtils")
local ColorPalette = require("ColorPalette")
local ValueObject = require("ValueObject")

local DARK_MODE_ENABLED = true

return function(target)
	local maid = Maid.new()

	local palette = ColorPalette.new()
	palette:SetDefaultSurfaceName("surface")
	palette:DefineColorSwatch("surface")
	palette:DefineColorSwatch("text")
	palette:DefineColorSwatch("accent")
	palette:DefineColorSwatch("action")
	palette:DefineColorGrade("surface")
	palette:DefineColorGrade("text")
	palette:DefineColorGrade("border")
	palette:DefineColorGrade("highlight")
	palette:DefineColorGrade("action")
	palette:DefineColorGrade("mouseOver")
	maid:GiveTask(palette)

	local function light()
		palette:SetColor("surface", Color3.fromRGB(245, 238, 214))
		palette:SetColor("text", Color3.fromRGB(96, 58, 58))
		palette:SetColor("accent", Color3.fromRGB(85, 170, 127))
		palette:SetColor("action", Color3.fromRGB(47, 28, 28))
		palette:SetColorGrade("surface", 5)
		palette:SetColorGrade("text", 75)
		palette:SetColorGrade("border", 25)
		palette:SetColorGrade("highlight", 20)
		palette:SetColorGrade("action", palette:ObserveColorBaseGradeBetween("action", 0, 30))
		palette:SetColorGrade("mouseOver", -15)
	end

	local function dark()
		palette:SetColor("surface", Color3.fromRGB(245, 238, 214))
		palette:SetColor("text", Color3.fromRGB(96, 58, 58))
		palette:SetColor("accent", Color3.fromRGB(85, 170, 127))
		palette:SetColor("action", Color3.fromRGB(47, 28, 28))
		palette:SetColorGrade("surface", 95, 0.1)
		palette:SetColorGrade("text", 30, 0.5)
		palette:SetColorGrade("border", 75, 0.1)
		palette:SetColorGrade("highlight", 70, 1)
		palette:SetColorGrade("action", palette:ObserveColorBaseGradeBetween("action", 70, 100), 0.1)
		palette:SetColorGrade("mouseOver", -15)
		palette:SetVividness("text", 0.5)
		palette:SetVividness("action", 0.5)
	end

	if DARK_MODE_ENABLED then
		dark()
	else
		light()
	end

	local function sampleGui(labelText)
		local mouseOver = ValueObject.new(0, "number")
		maid:GiveTask(mouseOver)

		local percentMouseOver = Blend.Spring(mouseOver, 60)

		return Blend.New "Frame" {
			BackgroundColor3 = palette:ObserveColor("surface");
			Size = UDim2.new(0, 250, 0, 100);

			[Blend.Children] = {
				Blend.New "TextLabel" {
					TextColor3 = palette:ObserveColor("text");
					Text = labelText;
					Font = Enum.Font.FredokaOne;
					Size = UDim2.new(1, 0, 1, 0);
					BackgroundTransparency = 1;
					TextScaled = true;
					ZIndex = 2;
				};

				Blend.New "UIPadding" {
					PaddingTop = UDim.new(0, 10);
					PaddingBottom = UDim.new(0, 10);
					PaddingLeft = UDim.new(0, 10);
					PaddingRight = UDim.new(0, 10);
				};

				Blend.New "UIStroke" {
					Color = palette:ObserveColor("surface", "border");
					Thickness = 5;
				};

				Blend.New "UICorner" {
					CornerRadius = UDim.new(0, 10);
				};

				Blend.New "Frame" {
					Name = "Highlight";
					Size = UDim2.new(0.8, 0, 0, 20);
					Position = UDim2.fromScale(0.5, 0.75);
					AnchorPoint = Vector2.new(0.5, 0.5);
					BackgroundColor3 = palette:ObserveColor("accent", "highlight");
					[Blend.Children] = {
						Blend.New "UICorner" {
							CornerRadius = UDim.new(0, 10);
						};
					};
				};

				Blend.New "Frame" {
					Name ="Button";
					Size = UDim2.new(0.5, 0, 0, 40);
					AnchorPoint = Vector2.new(1, 1);
					BackgroundColor3 = palette:GetSwatch("action"):ObserveGraded(
						palette:ObserveModifiedGrade("action", "mouseOver", percentMouseOver));
					Position = UDim2.new(1, 30, 1, 40);
					ZIndex = 2;

					[Blend.OnEvent "MouseEnter"] = function()
						mouseOver.Value = 1
					end;

					[Blend.OnEvent "MouseLeave"] = function()
						mouseOver.Value = 0
					end;

					[Blend.Children] = {
						Blend.New "UICorner" {
							CornerRadius = UDim.new(0, 10);
						};

						Blend.New "TextLabel" {
							TextColor3 = palette:ObserveColor("action", palette:ObserveModifiedGrade(
								palette:ObserveGradeOn("text", "action"),
								"mouseOver",
								percentMouseOver));
							Text = "Action";
							TextScaled = true;
							Font = Enum.Font.FredokaOne;
							Size = UDim2.new(1, 0, 1, 0);
							BackgroundTransparency = 1;
							ZIndex = 2;
						};

						[Blend.Children] = {
							Blend.New "UIStroke" {
								Color = palette:ObserveColor("action", palette:ObserveModifiedGrade(
									palette:ObserveGradeOn("border", "action"),
									"mouseOver",
									percentMouseOver));
								Thickness = 5;
							};
						};

						Blend.New "Frame" {
							Name = "Highlight";
							Size = UDim2.new(0.9, 0, 0, 10);
							Position = UDim2.fromScale(0.5, 0.75);
							AnchorPoint = Vector2.new(0.5, 0.5);
							BackgroundColor3 = palette:ObserveColor("accent", palette:ObserveGradeOn("highlight", "action"));
							[Blend.Children] = {
								Blend.New "UICorner" {
									CornerRadius = UDim.new(0, 10);
								};
							};
						};


						Blend.New "UIPadding" {
							PaddingTop = UDim.new(0, 5);
							PaddingBottom = UDim.new(0, 5);
							PaddingLeft = UDim.new(0, 5);
							PaddingRight = UDim.new(0, 5);
						};
					};
				};
			};
		};
	end


	maid:GiveTask((Blend.New "ScrollingFrame" {
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundColor3 = Color3.new(0, 0, 0);
		AutomaticCanvasSize = Enum.AutomaticSize.Y;
		CanvasSize = UDim2.new(1, 0, 0, 0);
		Parent = target;
		[Blend.Children] = {
			ColorPickerStoryUtils.create(maid, function(createPicker)
				createPicker("Surface", palette:GetColorValue("surface"));
				createPicker("Text", palette:GetColorValue("text"));
				createPicker("Accent", palette:GetColorValue("accent"));
				createPicker("Action", palette:GetColorValue("action"));
			end);

			Blend.New "Frame" {
				Size = UDim2.new(1, 0, 0, 0);
				BackgroundTransparency = 1;
				AutomaticSize = Enum.AutomaticSize.Y;

				[Blend.Children] = {
					sampleGui("Light");

					Blend.New "UIListLayout" {
						Padding = UDim.new(0, 50);
						HorizontalAlignment = Enum.HorizontalAlignment.Center;
						VerticalAlignment = Enum.VerticalAlignment.Top;
						FillDirection = Enum.FillDirection.Vertical;
					};
				};
			};


			Blend.New "UIListLayout" {
				Padding = UDim.new(0, 20);
				HorizontalAlignment = Enum.HorizontalAlignment.Center;
				VerticalAlignment = Enum.VerticalAlignment.Top;
				FillDirection = Enum.FillDirection.Vertical;
			};

			Blend.New "UIPadding" {
				PaddingTop = UDim.new(0, 10);
			};

			Blend.New "Frame" {
				Name = "TestCustomColor";
				Size = UDim2.new(0, 30, 0, 30);
				BackgroundColor3 = palette:ObserveColor(Color3.new(0, 0, 1), "text");
			};
		}
	}):Subscribe())


	return function()
		maid:DoCleaning()
	end
end