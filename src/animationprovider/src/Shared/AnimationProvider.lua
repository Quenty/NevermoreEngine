--- Provides animations for anything tagged with "AnimationContainer" and from a folder named "Animations"
-- in ReplicatedStorage.
-- @classmod AnimationProvider
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local TaggedTemplateProvider = require("TaggedTemplateProvider")

return TaggedTemplateProvider.new("AnimationContainer")