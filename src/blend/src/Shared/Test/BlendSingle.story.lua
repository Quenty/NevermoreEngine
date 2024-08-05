--[[
	@class BlendSingle.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local Observable = require("Observable")
local Blend = require("Blend")

return function(target)
	local maid = Maid.new()

	local state = Blend.State("a")

	local result = Blend.Single(Blend.Dynamic(state, function(text)
		return Blend.New "TextLabel" {
			Parent = target;
			Text = text;
			Size = UDim2.new(1, 0, 1, 0);
			BackgroundTransparency = 0.5;
			[function()
				return Observable.new(function()
					local internal = Maid.new()

					print("Made for", text)
					internal:GiveTask(function()
						print("Cleaning up", text)
					end)

					return internal
				end)
			end] = true;
		}
	end))


	maid:GiveTask(result:Subscribe())

	state.Value = "b"

	return function()
		maid:DoCleaning()
	end
end