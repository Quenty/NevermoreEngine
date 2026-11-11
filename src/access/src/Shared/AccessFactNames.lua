--!strict
--[=[
	The fact names the package itself registers.

	A fact name is API: it is what a spec overrides, what someone types into the console, and what a
	feature declares. Naming the ones this package ships means a game, a downstream package, and a console
	command all spell them the same way without having to coordinate.

	@class AccessFactNames
]=]

local AccessFactNames = {
	--[=[
		Whether the player has admin permission, per [PermissionService]. Registered at
		[AccessFactPriority].BUILT_IN, so anything a game registers outranks it.

		@prop PLAYER_IS_ADMIN string
		@within AccessFactNames
	]=]
	PLAYER_IS_ADMIN = "playerIsAdmin",

	--[=[
		Whether the player has bought this game, per [GameProductDataService]. The fact behind
		[WellKnownAccessFeatureNames].OWNS_GAME.

		@prop OWNS_GAME string
		@within AccessFactNames
	]=]
	OWNS_GAME = "ownsGame",
}

return AccessFactNames
