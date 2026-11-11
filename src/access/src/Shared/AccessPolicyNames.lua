--!strict
--[=[
	The policy names the package itself registers.

	Named for the same reason fact names are: a policy name is what a console user types and what a test
	addresses, so it is API rather than an internal label.

	@class AccessPolicyNames
]=]

local AccessPolicyNames = {
	--[=[
		Kicks anyone whose [AccessFactNames].PLAYER_IS_ADMIN reads false. Registered disabled.

		@prop KICK_ON_NON_ADMIN string
		@within AccessPolicyNames
	]=]
	KICK_ON_NON_ADMIN = "kick-on-non-admin",
}

return AccessPolicyNames
