---
-- @module FadeBetweenCamera.story
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")
local FadeBetweenCamera = require("FadeBetweenCamera")

return function(target)
	local maid = Maid.new()

	local fadeBetweenCamera = FadeBetweenCamera.new()
	maid:GiveTask(fadeBetweenCamera)

	return function()
		maid:DoCleaning()
	end
end