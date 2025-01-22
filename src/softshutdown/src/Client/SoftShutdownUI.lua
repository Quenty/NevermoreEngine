--[=[
	@class SoftShutdownUI
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local SpringObject = require("SpringObject")
local Rx = require("Rx")
local Math = require("Math")

local SoftShutdownUI = setmetatable({}, BasicPane)
SoftShutdownUI.ClassName = "SoftShutdownUI"
SoftShutdownUI.__index = SoftShutdownUI

function SoftShutdownUI.new()
	local self = setmetatable(BasicPane.new(), SoftShutdownUI)

	self._title = Instance.new("StringValue")
	self._title.Value = ""
	self._maid:GiveTask(self._title)

	self._subtitle = Instance.new("StringValue")
	self._subtitle.Value = ""
	self._maid:GiveTask(self._subtitle)

	self._percentVisible = self._maid:Add(SpringObject.new(0, 40))

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible, doNotAnimate)
		self._percentVisible.t = isVisible and 1 or 0
		if doNotAnimate then
			self._percentVisible.p = self._percentVisible.t
			self._percentVisible.v = 0
		end
	end))

	self._blur = Instance.new("BlurEffect")
	self._blur.Name = "SoftShutdownBlur"
	self._blur.Enabled = false
	self._blur.Size = 0
	self._blur.Parent = Workspace.CurrentCamera
	self._maid:GiveTask(self._blur)

	self._maid:GiveTask(self:_render():Subscribe(function(gui)
		self.Gui = gui
	end))

	return self
end

function SoftShutdownUI:SetTitle(text)
	self._title.Value = text
end

function SoftShutdownUI:SetSubtitle(text)
	self._subtitle.Value = text
end

function SoftShutdownUI:_render()
	local percentVisible = self._percentVisible:ObserveRenderStepped()
	local transparency = Blend.Computed(percentVisible, function(value)
		return 1 - value
	end)
	local backgroundColor = Color3.new(0, 0, 0)
	local foregroundColor = Color3.new(0.9, 0.9, 0.9)

	self._maid:GiveTask(percentVisible:Subscribe(function(percent)
		self._blur.Size = percent*30
		self._blur.Enabled = percent > 0
	end))

	return Blend.New "Frame" {
		Name = "SoftShutdownUI";
		Size = UDim2.new(1, 0, 1, 0);
		AnchorPoint = Vector2.new(0.5, 0.5);
		Position = UDim2.fromScale(0.5, 0.5);
		Active = Blend.Computed(percentVisible, function(visible)
			return visible > 0
		end);
		Visible = Blend.Computed(percentVisible, function(visible)
			return visible > 0
		end);
		BackgroundColor3 = backgroundColor;
		BackgroundTransparency = Blend.Computed(percentVisible, function(visible)
			return Math.map(visible, 0, 1, 1, 0.4)
		end);

		[Blend.Children] = {
			Blend.New "UIPadding" {
				PaddingLeft = UDim.new(0, 20);
				PaddingRight = UDim.new(0, 20);
				PaddingTop = UDim.new(0, 20);
				PaddingBottom = UDim.new(0, 20);
			};

			Blend.New "Frame" {
				Name = "ContentContainer";
				Size = UDim2.new(1, 0, 1, 0);
				AnchorPoint = Vector2.new(0.5, 0.5);
				Position = UDim2.fromScale(0.5, 0.5);
				BackgroundTransparency = 1;

				[Blend.Children] = {
					Blend.New "UIScale" {
						Scale = Blend.Computed(percentVisible, function(visible)
							return 0.7 + 0.3*visible
						end);
					};

					Blend.New "Frame" {
						Name = "ImageLabelContainer";
						Size = UDim2.new(0, 80, 0, 80);
						BackgroundTransparency = 1;
						LayoutOrder = 1;

						[Blend.Children] = {
							Blend.New "ImageLabel" {
								Size = UDim2.new(1, 0, 1, 0);
								ImageTransparency = transparency;
								BackgroundTransparency = 1;
								Image = "rbxassetid://6031302916";
							};
						};
					};

					Blend.New "Frame" {
						Name = "LabelContainer";
						Size = UDim2.new(1, 0, 0, 80);
						Position = UDim2.new(0.5, 0, 0.5,0);
						AnchorPoint = Vector2.new(0.5, 0.5);
						BackgroundTransparency = 1;
						LayoutOrder = 2;

						[Blend.Children] = {
							Blend.New "TextLabel" {
								Name = "TitleLabel";
								BackgroundTransparency = 1;
								Position = UDim2.fromScale(0.5, 0);
								Size = UDim2.new(1, 0, 0.6, 0);
								AnchorPoint = Vector2.new(0.5, 0);
								Text = self._title;
								Font = Enum.Font.SourceSansBold;
								TextTransparency = transparency;
								TextColor3 = foregroundColor;
								LayoutOrder = 1;
								TextScaled = true;
							};

							Blend.New "TextLabel" {
								Name = "SubtitleLabel";
								BackgroundTransparency = 1;
								Position = UDim2.fromScale(0.5, 1);
								Size = UDim2.new(1, 0, 0.3, 0);
								AnchorPoint = Vector2.new(0.5, 1);
								Text = self._subtitle;
								Font = Enum.Font.SourceSansLight;
								TextTransparency = transparency;
								TextColor3 = foregroundColor;
								LayoutOrder = 2;
								TextScaled = true;
							};

							Blend.New "UIAspectRatioConstraint" {
								AspectRatio = 5;
							};
						};
					};

					Blend.New "Frame" {
						Name = "Spacer";
						BackgroundTransparency = 1;
						Size = UDim2.new(0, 0, 0, 50);
						LayoutOrder = 3;
					};

					Blend.New "Frame" {
						Name = "LoadingLabel";
						Position = UDim2.fromScale(0.5, 0.5);
						AnchorPoint = Vector2.new(0.5, 0.5);
						LayoutOrder = 4;
						Size = UDim2.fromScale(0.25, 0.25);
						BackgroundTransparency = 1;

						[Blend.Children] = {
							Blend.New "Frame" {
								Name = "RobloxLogo";
								Size = UDim2.new(1, 0, 1, 0);
								BackgroundColor3 = foregroundColor;
								AnchorPoint = Vector2.new(0.5, 0.5);
								Position = UDim2.fromScale(0.5, 0.5);

								BackgroundTransparency = transparency;
								Rotation = Rx.fromSignal(RunService.RenderStepped):Pipe({
									Rx.map(function()
										-- tick persists between sessions
										local t = tick()*math.pi*1.5
										local smallerWave = math.sin(t)
										local percent = (math.sin(t - math.pi/2) + 1)/2

										if smallerWave > 0 then
											return 15 + percent*360
										else
											return 15
										end
									end);
								});

								[Blend.Children] = {
									Blend.New "Frame" {
										BackgroundColor3 = backgroundColor;
										Size = UDim2.fromScale(4/14, 4/14);
										AnchorPoint = Vector2.new(0.5, 0.5);
										Position = UDim2.fromScale(0.5, 0.5);
										BackgroundTransparency = transparency;
									};
								}
							};

							Blend.New "UIAspectRatioConstraint" {
								AspectRatio = 1;
							};

							Blend.New "UISizeConstraint" {
								MaxSize = Vector2.new(math.huge, 50);
							};
						};
					};

					Blend.New "UIListLayout" {
						FillDirection = Enum.FillDirection.Vertical;
						SortOrder = Enum.SortOrder.LayoutOrder;
						HorizontalAlignment = Enum.HorizontalAlignment.Center;
						VerticalAlignment = Enum.VerticalAlignment.Center;
						Padding = UDim.new(0, 10);
					};
				};
			};
		};
	}
end

return SoftShutdownUI