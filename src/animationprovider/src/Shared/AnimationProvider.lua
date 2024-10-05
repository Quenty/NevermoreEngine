--[=[
	Provides animations for anything tagged with "AnimationContainer" and from a folder named "Animations"
	in ReplicatedStorage. See [TemplateProvider].

	@class AnimationProvider
]=]

local require = require(script.Parent.loader).load(script)

local TaggedTemplateProvider = require("TaggedTemplateProvider")

return TaggedTemplateProvider.new(script.Name, "AnimationContainer")