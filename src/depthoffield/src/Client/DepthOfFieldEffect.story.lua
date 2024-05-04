--[[
	@class DepthOfFieldEffect.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Workspace = game:GetService("Workspace")

local Maid = require("Maid")
local DepthOfFieldEffect = require("DepthOfFieldEffect")
local Blend = require("Blend")

return function(target)
	local maid = Maid.new()

	local depthOfFieldEffect = maid:Add(DepthOfFieldEffect.new())
	depthOfFieldEffect:SetShowSpeed(10)
	depthOfFieldEffect.Gui.Parent = Workspace.CurrentCamera
	depthOfFieldEffect:Show()

	local depthOfFieldEffect2 = maid:Add(DepthOfFieldEffect.new())
	depthOfFieldEffect2:SetFocusDistanceTarget(100, true)
	depthOfFieldEffect2:SetInFocusRadiusTarget(50, true)
	depthOfFieldEffect2:SetShowSpeed(10)
	depthOfFieldEffect2.Gui.Parent = Workspace.CurrentCamera
	-- depthOfFieldEffect2:Show()


	maid:Add(Blend.mount(target, {
		Blend.New "Frame" {
			Size = UDim2.new(1, 0, 1, 0);
			BackgroundTransparency = 1;

			Blend.New "UIListLayout" {
				Padding = UDim.new(0, 5);
			};

			Blend.New "TextButton" {
				Text = Blend.Computed(depthOfFieldEffect:ObserveVisible(), function(visible)
					return string.format("Toggle 1 (%s)", visible and "on" or "off")
				end);
				BackgroundColor3 = Blend.Computed(depthOfFieldEffect:ObserveVisible(), function(visible)
					return visible and Color3.new(0.5, 1, 0.5) or Color3.new(1, 0.5, 0.5)
				end);
				AutoButtonColor = true;
				Size = UDim2.new(0, 100, 0, 30);
				[Blend.OnEvent "Activated"] = function()
					depthOfFieldEffect:Toggle()
				end;

				Blend.New "UICorner" {
					CornerRadius = UDim.new(0, 5);
				};
			};

			Blend.New "TextButton" {
				Text = Blend.Computed(depthOfFieldEffect2:ObserveVisible(), function(visible)
					return string.format("Toggle 2 (%s)", visible and "on" or "off")
				end);
				BackgroundColor3 = Blend.Computed(depthOfFieldEffect2:ObserveVisible(), function(visible)
					return visible and Color3.new(0.5, 1, 0.5) or Color3.new(1, 0.5, 0.5)
				end);
				AutoButtonColor = true;
				Size = UDim2.new(0, 100, 0, 30);
				[Blend.OnEvent "Activated"] = function()
					depthOfFieldEffect2:Toggle()
				end;

				Blend.New "UICorner" {
					CornerRadius = UDim.new(0, 5);
				};
			};
		};
	}))

	return function()
		maid:DoCleaning()
	end
end