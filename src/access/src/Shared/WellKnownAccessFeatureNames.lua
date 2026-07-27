--!strict
--[=[
	The feature names the package itself registers.

	Shipping a name means every game gates the same capability by the same string, and a package that
	wants to widen it has something to widen. See [AccessFeature.PushFactAllowsFeature].

	@class WellKnownAccessFeatureNames
]=]

local WellKnownAccessFeatureNames = {
	--[=[
		Whether the player owns the game. Ships reading a real purchase and nothing else -- a game adds its
		own ways in by pushing facts onto it rather than by replacing it.

		@prop OWNS_GAME string
		@within WellKnownAccessFeatureNames
	]=]
	OWNS_GAME = "owns-game",
}

return WellKnownAccessFeatureNames
