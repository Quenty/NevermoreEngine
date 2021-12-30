--[[
	@class BlendTextbox.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).load(script)

local Blend = require("Blend")
local Maid = require("Maid")

return function(target)
	local maid = Maid.new()

	local state = Blend.State("hi")

	maid:GiveTask((Blend.New "Frame" {
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		Parent = target;

		[Blend.Children] = {
			Blend.New "TextBox" {
				Size = UDim2.new(0, 200, 0, 50);
				Text = state;
				[Blend.OnChange "Text"] = state;
				[Blend.OnEvent "Focused"] = function()
					print("Focused")
				end;

				[function(inst) return inst.Focused end] = function()
					print("Focused (via func)")
				end;

				-- this also works
				[function(inst) return inst:GetPropertyChangedSignal("Text") end] = function()
					print("Property changed from :GetPropertyChangedSignal()")
				end;
			};

			Blend.New "TextBox" {
				Size = UDim2.new(0, 200, 0, 50);
				[Blend.OnChange "Text"] = state; -- read state
				Text = state; -- write state
			};

			Blend.New "UIListLayout" {
				Padding = UDim.new(0, 10);
			};
		};
	}):Subscribe())

	return function()
		maid:DoCleaning()
	end
end