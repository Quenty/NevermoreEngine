--[[
	@class snackbarServiceClient.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local SnackbarServiceClient = require("SnackbarServiceClient")
local ScreenGuiService = require("ScreenGuiService")
local LipsumUtils = require("LipsumUtils")
local Blend = require("Blend")

return function(target)
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())

	local snackbarServiceClient = serviceBag:GetService(SnackbarServiceClient)
	maid:GiveTask(serviceBag:GetService(ScreenGuiService):SetGuiParent(target))

	serviceBag:Init()
	serviceBag:Start()

	local function showSnackBar()
		snackbarServiceClient:ShowSnackbar(LipsumUtils.sentence(10), {
			CallToAction = {
				Text = LipsumUtils.word();
				OnClick = function()
					print("Activated action")
				end;
			}
		})
	end

	local function button(props)
		return Blend.New "TextButton" {
			AutomaticSize = Enum.AutomaticSize.XY;
			AutoButtonColor = true;
			Text = props.Text;
			[Blend.OnEvent "Activated"] = props.OnActivated;

			Blend.New "UIPadding" {
				PaddingTop = UDim.new(0, 10);
				PaddingBottom = UDim.new(0, 10);
				PaddingLeft = UDim.new(0, 10);
				PaddingRight = UDim.new(0, 10);
			};

			Blend.New "UICorner" {
				CornerRadius = UDim.new(0, 5);
			}
		};
	end

	showSnackBar()

	maid:GiveTask(Blend.mount(target, {
		Blend.New "Frame" {
			AutomaticSize = Enum.AutomaticSize.XY;
			AnchorPoint = Vector2.new(0.5, 0);
			Position = UDim2.fromScale(0.5, 0);
			BackgroundTransparency = 1;

			Blend.New "UIPadding" {
				PaddingTop = UDim.new(0, 5);
				PaddingBottom = UDim.new(0, 5);
				PaddingLeft = UDim.new(0, 5);
				PaddingRight = UDim.new(0, 5);
			};

			Blend.New "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal;
				Padding = UDim.new(0, 5);
			};

			button({
				Text = "Show snackbar";
				OnActivated = showSnackBar;
			});
			button({
				Text = "Clear queue";
				OnActivated = function()
					snackbarServiceClient:ClearQueue()
				end;
			});
			button({
				Text = "Hide current";
				OnActivated = function()
					snackbarServiceClient:HideCurrent()
				end;
			});
		};
	}))

	return function()
		maid:DoCleaning()
	end
end