--[[
	@class ColorGradePalette.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local Blend = require("Blend")
local ColorGradePalette = require("ColorGradePalette")
local ColorSwatch = require("ColorSwatch")
local ColorPickerStoryUtils = require("ColorPickerStoryUtils")
local ValueObject = require("ValueObject")

return function(target)
	local maid = Maid.new()

	local surfaceColorValue = ValueObject.new(Color3.fromRGB(245, 238, 214))
	local surface = ColorSwatch.new(surfaceColorValue)
	maid:GiveTask(surface)
	maid:GiveTask(surfaceColorValue)

	local textColorValue = ValueObject.new(Color3.fromRGB(96, 58, 58))
	local text = ColorSwatch.new(textColorValue)
	maid:GiveTask(text)
	maid:GiveTask(textColorValue)

	local accentColorValue = ValueObject.new(Color3.fromRGB(85, 170, 127))
	local accent = ColorSwatch.new(accentColorValue)
	maid:GiveTask(accentColorValue)
	maid:GiveTask(accent)

	local actionColorValue = ValueObject.new(Color3.fromRGB(47, 28, 28))
	local action = ColorSwatch.new(actionColorValue)
	maid:GiveTask(action)
	maid:GiveTask(actionColorValue)

	local light = ColorGradePalette.new()
	light:SetDefaultSurfaceName("surface")
	light:Add("surface", 5)
	light:Add("text", 75)
	light:Add("border", 25)
	light:Add("highlight", 20)
	light:Add("action", action:ObserveBaseGradeBetween(0, 30))
	light:Add("mouseOver", -15)

	local dark = ColorGradePalette.new()
	dark:SetDefaultSurfaceName("surface")
	dark:Add("surface", 95, 0.1)
	dark:Add("text", 30, 0.5)
	dark:Add("border", 75, 0.1)
	dark:Add("highlight", 70, 1)
	dark:Add("action", action:ObserveBaseGradeBetween(70, 100), 0.1)
	dark:Add("mouseOver", -15)

	local function sampleGui(labelText, gradePalette)
		local mouseOver = ValueObject.new(0, "number")
		maid:GiveTask(mouseOver)

		local percentMouseOver = Blend.Spring(mouseOver, 60)

		return Blend.New "Frame" {
			BackgroundColor3 = surface:ObserveGraded(gradePalette:ObserveGrade("surface"));
			Size = UDim2.new(0, 250, 0, 100);

			[Blend.Children] = {
				Blend.New "TextLabel" {
					TextColor3 = text:ObserveGraded(gradePalette:ObserveGrade("text"));
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
					Color = surface:ObserveGraded(gradePalette:ObserveGrade("border"));
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
					BackgroundColor3 = accent:ObserveGraded(gradePalette:ObserveGrade("highlight"));
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
					BackgroundColor3 = action:ObserveGraded(gradePalette:ObserveModified("action", "mouseOver", percentMouseOver));
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
							TextColor3 = action:ObserveGraded(gradePalette:ObserveModified(gradePalette:ObserveOn("text", "action"), "mouseOver", percentMouseOver));
							Text = "Action";
							TextScaled = true;
							Font = Enum.Font.FredokaOne;
							Size = UDim2.new(1, 0, 1, 0);
							BackgroundTransparency = 1;
							ZIndex = 2;
						};

						[Blend.Children] = {
							Blend.New "UIStroke" {
								Color = action:ObserveGraded(gradePalette:ObserveModified(gradePalette:ObserveOn("border", "action"), "mouseOver", percentMouseOver));
								Thickness = 5;
							};
						};

						Blend.New "Frame" {
							Name = "Highlight";
							Size = UDim2.new(0.9, 0, 0, 10);
							Position = UDim2.fromScale(0.5, 0.75);
							AnchorPoint = Vector2.new(0.5, 0.5);
							BackgroundColor3 = accent:ObserveGraded(gradePalette:ObserveOn("highlight", "action"));
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
				createPicker("Surface", surfaceColorValue);
				createPicker("Text", textColorValue);
				createPicker("Accent", accentColorValue);
				createPicker("Action", actionColorValue);
			end);


			Blend.New "Frame" {
				Size = UDim2.new(1, 0, 0, 0);
				BackgroundTransparency = 1;
				AutomaticSize = Enum.AutomaticSize.Y;

				[Blend.Children] = {
					sampleGui("Light", light);
					sampleGui("Dark", dark);

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
		}
	}):Subscribe())


	return function()
		maid:DoCleaning()
	end
end