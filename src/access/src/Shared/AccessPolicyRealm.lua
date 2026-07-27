--!strict
--[=[
	Which realm a policy's consequence runs in.

	Policies are registered in **both** realms regardless, so a console on either side knows every policy
	name and can autocomplete it. The realm decides only where `apply` actually runs -- kicking is
	server-side, showing a piece of UI is client-side, and neither should half-happen on the wrong one.

	@class AccessPolicyRealm
]=]

local AccessPolicyRealm = {
	--[=[
		Runs only on the server. Enforcement: kicking, teleporting, refusing to spawn.
		@prop SERVER string
		@within AccessPolicyRealm
	]=]
	SERVER = "server",

	--[=[
		Runs only on the client. Presentation: showing a locked banner, hiding a button.
		@prop CLIENT string
		@within AccessPolicyRealm
	]=]
	CLIENT = "client",

	--[=[
		Runs in both. Rare -- most consequences belong to one side.
		@prop BOTH string
		@within AccessPolicyRealm
	]=]
	BOTH = "both",
}

--[=[
	Whether a policy declaring this realm should run where we are.

	@param realm string
	@param isServer boolean
	@return boolean
]=]
function AccessPolicyRealm.runsHere(realm: string, isServer: boolean): boolean
	if realm == AccessPolicyRealm.BOTH then
		return true
	end

	return realm == (if isServer then AccessPolicyRealm.SERVER else AccessPolicyRealm.CLIENT)
end

return AccessPolicyRealm
