--!strict
--[=[
	A policy whose consequence is kicking. What *triggers* it is the binding.

	Behaviour and application are separated on purpose: kicking is one thing, and "when someone is not
	staff" is another. Bind them at the registration site, where both halves read in a line:

	```lua
	maid:GiveTask(accessPolicyService:RegisterPolicy(
		maid:Add(AccessKickPolicy.whenFactIs(serviceBag, "kick-on-non-admin", AccessFactNames.PLAYER_IS_ADMIN, false, {
			message = "This place is currently limited to the development team.",
		}))
	))

	maid:GiveTask(accessPolicyService:RegisterPolicy(
		maid:Add(AccessKickPolicy.whenFeatureDisallowed(serviceBag, "kick-without-chapter-access", MyFeatures.Chapters))
	))
	```

	GOTCHA, and the reason this is a class rather than a pattern to copy: **a kick never fires on an
	unanswered input.** "We could not find out whether you are staff" is not "you are not staff", and a
	policy that kicked on the difference would empty the server every time a lookup hiccupped. Both
	bindings below encode that once -- `whenFactIs` matches the value exactly, so unresolved never equals
	`false`; `whenFeatureDisallowed` skips [AccessStateUtils.isUnresolved], which an author writing
	`not isAllowed(state)` by hand would silently get wrong.

	@class AccessKickPolicy
]=]

local require = require(script.Parent.loader).load(script)

local AccessFeature = require("AccessFeature")
local AccessPolicy = require("AccessPolicy")
local AccessPolicyRealm = require("AccessPolicyRealm")
local AccessStateUtils = require("AccessStateUtils")
local Observable = require("Observable")
local PlayerMock = require("PlayerMock")
local Rx = require("Rx")

local AccessKickPolicy = {}

local DEFAULT_MESSAGE = "You do not have access to this place."

--[=[
	Emits true when this player should be kicked. Anything it never emits true for never kicks.

	@type AccessKickTrigger (AccessPolicyContext) -> Observable<boolean>
	@within AccessKickPolicy
]=]
export type AccessKickTrigger = (context: AccessPolicy.AccessPolicyContext) -> Observable.Observable<boolean>

export type AccessKickPolicyOptions = {
	policyName: string,
	facts: { string }?,
	features: { AccessFeature.AccessFeature }?,
	message: string?,
	isEnabledByDefault: boolean?,
	observeShouldKick: AccessKickTrigger,
}

--[=[
	The general form. Prefer [AccessKickPolicy.whenFactIs] or
	[AccessKickPolicy.whenFeatureDisallowed] -- they read better and they get the unresolved rule right
	without you having to remember it.

	@param serviceBag ServiceBag
	@param options AccessKickPolicyOptions
	@return AccessPolicy
]=]
function AccessKickPolicy.new(serviceBag: any, options: AccessKickPolicyOptions): AccessPolicy.AccessPolicy
	assert(type(options) == "table", "Bad options")
	assert(type(options.observeShouldKick) == "function", "Bad options.observeShouldKick")
	assert(type(options.message) == "string" or options.message == nil, "Bad options.message")

	local message = options.message or DEFAULT_MESSAGE

	return AccessPolicy.new(serviceBag, {
		policyName = options.policyName,
		facts = options.facts,
		features = options.features,
		-- Kicking is enforcement. The client registers this policy too, so its name autocompletes, but
		-- only the server ever runs it.
		realm = AccessPolicyRealm.SERVER,
		isEnabledByDefault = options.isEnabledByDefault,
		apply = function(context)
			return options.observeShouldKick(context):Subscribe(function(shouldKick: boolean)
				if shouldKick then
					AccessKickPolicy.kick(context.player, message)
				end
			end)
		end,
	})
end

--[=[
	Kicks while a fact reads exactly this value.

	`AccessKickPolicy.whenFactIs("kick-on-non-admin", "playerIsAdmin", false)` reads as what it does:
	kick when playerIsAdmin is false. Unresolved is not false, so an unanswered lookup kicks nobody.

	@param serviceBag ServiceBag
	@param policyName string
	@param factName string
	@param value boolean
	@param options { message: string?, isEnabledByDefault: boolean? }?
	@return AccessPolicy
]=]
function AccessKickPolicy.whenFactIs(
	serviceBag: any,
	policyName: string,
	factName: string,
	value: boolean,
	options: { message: string?, isEnabledByDefault: boolean? }?
): AccessPolicy.AccessPolicy
	assert(type(factName) == "string", "Bad factName")
	assert(type(value) == "boolean", "Bad value")

	return AccessKickPolicy.new(serviceBag, {
		policyName = policyName,
		facts = { factName },
		message = if options then options.message else nil,
		isEnabledByDefault = if options then options.isEnabledByDefault else nil,
		observeShouldKick = function(context)
			return context.observeFact(factName):Pipe({
				Rx.map(function(current: boolean?)
					return current == value
				end) :: any,
			}) :: any
		end,
	})
end

--[=[
	Kicks while a feature refuses this player for a real reason.

	Skips unresolved, which is the whole trap: an unresolved state *is* a disallowed state, so the obvious
	`not isAllowed(state)` would kick everyone whose lookup had not landed yet.

	@param serviceBag ServiceBag
	@param policyName string
	@param feature AccessFeature
	@param options { message: string?, isEnabledByDefault: boolean? }?
	@return AccessPolicy
]=]
function AccessKickPolicy.whenFeatureDisallowed(
	serviceBag: any,
	policyName: string,
	feature: AccessFeature.AccessFeature,
	options: { message: string?, isEnabledByDefault: boolean? }?
): AccessPolicy.AccessPolicy
	assert(AccessFeature.isAccessFeature(feature), "Bad feature")

	return AccessKickPolicy.new(serviceBag, {
		policyName = policyName,
		features = { feature },
		message = if options then options.message else nil,
		isEnabledByDefault = if options then options.isEnabledByDefault else nil,
		observeShouldKick = function(context)
			return context.observeFeature(feature):Pipe({
				Rx.map(function(state: AccessStateUtils.AccessState)
					return not AccessStateUtils.isAllowed(state) and not AccessStateUtils.isUnresolved(state)
				end) :: any,
			}) :: any
		end,
	})
end

--[=[
	Kicks the player, mock or otherwise. A [PlayerMock] has no native `Kick`, and a policy that only works
	against real players cannot be tested without a real session.

	@param player Player
	@param message string
]=]
function AccessKickPolicy.kick(player: Player, message: string): ()
	if PlayerMock.isMock(player) then
		PlayerMock.kick(player, message)
	else
		player:Kick(message)
	end
end

return AccessKickPolicy
