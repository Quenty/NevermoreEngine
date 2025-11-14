--[[
	@class Blend.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Blend = require("Blend")
local Maid = require("Maid")

return function(target)
	local maid = Maid.new()

	local state = Blend.State({ "a", "b", "c" })
	maid:GiveTask(state)

	maid:GiveTask((Blend.New "TextLabel" {
		Parent = target,

		[Blend.Children] = {
			Blend.New "TextButton" {
				Text = "Add",
				AutoButtonColor = true,
				Size = UDim2.fromOffset(100, 20),
				[Blend.OnEvent "Activated"] = function()
					local newState = {}
					for _, item in state.Value do
						table.insert(newState, item)
					end
					table.insert(newState, string.char(string.byte("a") + #newState))
					state.Value = newState
				end,
			},
			Blend.ComputedPairs(state, function(_index, value)
				print("Compute", value)
				return Blend.New "TextLabel" {
					Text = tostring(value),
					Size = UDim2.fromOffset(20, 20),
				}
			end),

			Blend.New "UIListLayout" {
				Padding = UDim.new(0, 5),
			},
		},
	}):Subscribe())

	return function()
		maid:DoCleaning()
	end
end
