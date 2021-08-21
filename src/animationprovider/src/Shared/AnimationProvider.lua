--- Provides animations for anything tagged with "AnimationContainer" and from a folder named "Animations"
-- in ReplicatedStorage.
-- @classmod AnimationProvider
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TaggedTemplateProvider = require("TaggedTemplateProvider")

local provider = TaggedTemplateProvider.new("AnimationContainer")

-- This is a fallback animation setup
local animations = ReplicatedStorage:FindFirstChild("Animations")
if animations then
	provider:AddContainer(animations)
end

return provider