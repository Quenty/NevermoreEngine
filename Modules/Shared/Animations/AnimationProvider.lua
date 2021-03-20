---
-- @classmod AnimationProvider
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TaggedTemplateProvider = require("TaggedTemplateProvider")

local provider = TaggedTemplateProvider.new("AnimationContainer")

-- This is a fallback animation setup
local animations = ReplicatedStorage:FindFirstChild("Animations")
if animations then
	provider:AddContainer(animations)
end

return provider