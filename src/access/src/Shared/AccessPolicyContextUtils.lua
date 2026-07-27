--!strict
--[=[
	The thing an [AccessPolicy] is handed when it runs. A named concept with a checked shape rather than
	an anonymous table, because a policy author reads this before they write anything, and "what do I get
	and what may I do with it" should be answerable in one place.

	```lua
	apply = function(context)
		return context.observeFact(AccessFactNames.PLAYER_IS_ADMIN):Subscribe(function(isAdmin)
			if isAdmin == false then
				kick(context.player)
			end
		end)
	end
	```

	`observeFact` and `observeFeature` refuse anything the policy did not declare, so what a readout says
	a policy depends on is the whole truth about its inputs.

	@class AccessPolicyContextUtils
]=]

local require = require(script.Parent.loader).load(script)

local PlayerMock = require("PlayerMock")
local t = require("t")

local AccessPolicyContextUtils = {}

--[=[
	@interface AccessPolicyContext
	.player Player
	.observeFact (factName: string) -> Observable<boolean?>
	.observeFeature (feature: AccessFeature, subject: any?) -> Observable<AccessState>
	@within AccessPolicyContextUtils
]=]
export type AccessPolicyContext = {
	player: Player,
	observeFact: (factName: string) -> any,
	observeFeature: (feature: any, subject: any?) -> any,
}

-- A mock is a Player as far as every policy is concerned, and refusing one here would make policies
-- untestable without a real session.
local function isPlayerLike(value: any): (boolean, string?)
	if typeof(value) == "Instance" and value:IsA("Player") then
		return true
	elseif PlayerMock.isMock(value) then
		return true
	end

	return false, `expected a Player, got {typeof(value)}`
end

--[=[
	@prop isAccessPolicyContext (any) -> (boolean, string?)
	@within AccessPolicyContextUtils
]=]
AccessPolicyContextUtils.isAccessPolicyContext = t.strictInterface({
	player = isPlayerLike,
	observeFact = t.callback,
	observeFeature = t.callback,
} :: any) :: (any) -> (boolean, string?)

--[=[
	Builds a context, asserting its shape. Strict rather than lenient: a context missing a member fails
	here, where the message names it, instead of inside somebody's policy as a nil call.

	@param context AccessPolicyContext
	@return AccessPolicyContext
]=]
function AccessPolicyContextUtils.create(context: AccessPolicyContext): AccessPolicyContext
	assert(AccessPolicyContextUtils.isAccessPolicyContext(context :: any))

	return context
end

return AccessPolicyContextUtils
