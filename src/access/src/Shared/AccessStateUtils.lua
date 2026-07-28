--!strict
--[=[
	The verdict an [AccessFeature] produces, and the fold most features want.

	Three outcomes, not two. `disallowed(UNRESOLVED)` means no answer came back yet -- a lookup still in
	flight, a service that failed, a realm that cannot resolve a fact at all -- and it is deliberately not
	the same as being denied. Each consumer decides what an unanswered question means for it: a storefront
	may offer on it, an enforcement gate must never open on it.

	@class AccessStateUtils
]=]

local require = require(script.Parent.loader).load(script)

local AccessFactContributionState = require("AccessFactContributionState")
local AccessFactContributionStateUtils = require("AccessFactContributionStateUtils")

local AccessStateUtils = {}

--[=[
	The reasons this module produces on its own. A feature is free to return any other string; these are
	the two that fall out of the fact fold rather than out of game policy.

	@prop Reasons { UNRESOLVED: string, NOT_GRANTED: string }
	@within AccessStateUtils
]=]
AccessStateUtils.Reasons = {
	UNRESOLVED = "unresolved",
	NOT_GRANTED = "notGranted",
}

export type AccessAllowedState = {
	type: "allowed",
	grantedBy: { string },
}

export type AccessDisallowedState = {
	type: "disallowed",
	reason: string,
}

--[=[
	@type AccessState AccessAllowedState | AccessDisallowedState
	@within AccessStateUtils
]=]
export type AccessState = AccessAllowedState | AccessDisallowedState

--[=[
	Every declared fact and what it said, as an [AccessFactContributionState].

	Always present, never nil: a Lua table cannot hold a nil, so the old `boolean?` map silently lost
	exactly the facts that had not answered -- the ones a gate most needs to know about.

	@type AccessFactState { [string]: string }
	@within AccessStateUtils
]=]
export type AccessFactState = { [string]: string }

--[=[
	Allowed, listing every fact that granted rather than the first one found. Callers surface `grantedBy`
	in debug output, so a state that was granted three ways says so.

	@param grantedBy { string }?
	@return AccessAllowedState
]=]
function AccessStateUtils.allowed(grantedBy: { string }?): AccessAllowedState
	return { type = "allowed", grantedBy = grantedBy or {} }
end

--[=[
	@param reason string
	@return AccessDisallowedState
]=]
function AccessStateUtils.disallowed(reason: string): AccessDisallowedState
	assert(type(reason) == "string", "Bad reason")

	return { type = "disallowed", reason = reason }
end

--[=[
	@return AccessDisallowedState
]=]
function AccessStateUtils.unresolved(): AccessDisallowedState
	return AccessStateUtils.disallowed(AccessStateUtils.Reasons.UNRESOLVED)
end

--[=[
	@param state AccessState
	@return boolean
]=]
function AccessStateUtils.isAllowed(state: AccessState): boolean
	return state.type == "allowed"
end

--[=[
	Whether a state is specifically unresolved, for the callers that must not act on a non-answer.

	@param state AccessState
	@return boolean
]=]
function AccessStateUtils.isUnresolved(state: AccessState): boolean
	return state.type == "disallowed" and state.reason == AccessStateUtils.Reasons.UNRESOLVED
end

--[=[
	Two states are the same verdict when they deny for the same reason, or grant on the same facts.

	@param state AccessState
	@return string
]=]
function AccessStateUtils.key(state: AccessState): string
	if state.type == "allowed" then
		return `allowed:{table.concat(state.grantedBy, ",")}`
	end

	return `disallowed:{state.reason}`
end

--[=[
	The fold most features want: any true fact allows, an unanswered fact leaves it unresolved, and only a
	complete set of false answers denies.

	Order matters. A true fact wins even while another is still unresolved, because an answer that already
	grants cannot be changed by one that hasn't arrived -- waiting for it would keep an entitled player out
	for no reason.

	@param factState AccessFactState
	@param factNames { string }
	@return AccessState
]=]
function AccessStateUtils.fromFacts(factState: AccessFactState, factNames: { string }): AccessState
	local grantedBy = {}
	local anyUnresolved = false

	for _, factName in factNames do
		local state = factState[factName]
		if state == AccessFactContributionState.ALLOW then
			table.insert(grantedBy, factName)
		elseif state ~= AccessFactContributionState.DENY then
			-- Unresolved, abstained, or a fact nothing answered: all of them mean "not a no", and a gate
			-- must not read any of them as one.
			anyUnresolved = true
		end
	end

	if #grantedBy > 0 then
		return AccessStateUtils.allowed(grantedBy)
	elseif anyUnresolved then
		return AccessStateUtils.unresolved()
	end

	return AccessStateUtils.disallowed(AccessStateUtils.Reasons.NOT_GRANTED)
end

--[=[
	Granted only when **every** named fact allows, unresolved while any is unanswered, refused as soon as
	one denies.

	The and-of that every flag-gated grant actually is -- `isEarlyAccessTester` *and*
	`testerEarlyAccessEnabled` -- so a feature can declare its shape rather than hand-write the fold.

	@param factState AccessFactState
	@param factNames { string }
	@return AccessState
]=]
function AccessStateUtils.fromAllFacts(factState: AccessFactState, factNames: { string }): AccessState
	local anyUnresolved = false

	for _, factName in factNames do
		local state = factState[factName]
		if state == AccessFactContributionState.DENY then
			-- A definite no ends it. Unlike an any-of, no later answer can rescue an and-of, so there is
			-- nothing to wait for and reporting unresolved would be a stall with a known answer behind it.
			return AccessStateUtils.disallowed(AccessStateUtils.Reasons.NOT_GRANTED)
		elseif state ~= AccessFactContributionState.ALLOW then
			anyUnresolved = true
		end
	end

	if anyUnresolved then
		return AccessStateUtils.unresolved()
	end

	return AccessStateUtils.allowed(table.clone(factNames))
end

--[=[
	Granted when every named fact is definitely **false**, unresolved while any is unanswered.

	The gate "does not own the game" needs this rather than a `not`: inverting the value turns unresolved
	into true, which is the difference between "we could not confirm" and "definitely does not own it" --
	and on a purchase gate that difference is offering to sell something somebody already has.

	@param factState AccessFactState
	@param factNames { string }
	@return AccessState
]=]
function AccessStateUtils.fromNoFacts(factState: AccessFactState, factNames: { string }): AccessState
	local inverted = {}
	for _, factName in factNames do
		inverted[factName] =
			AccessFactContributionStateUtils.invert(factState[factName] or AccessFactContributionState.UNRESOLVED)
	end

	return AccessStateUtils.fromAllFacts(inverted, factNames)
end

--[=[
	The first allowed verdict among these, else unresolved if any is, else the first refusal.

	An or-fold over whole verdicts rather than over facts, which is what lets a composed feature keep both
	halves' reasoning instead of collapsing to a boolean on the way.

	@param states { AccessState }
	@return AccessState
]=]
function AccessStateUtils.anyAllowed(states: { AccessState }): AccessState
	local grantedBy = {}
	local anyUnresolved = false

	for _, state in states do
		if AccessStateUtils.isAllowed(state) then
			for _, name in (state :: any).grantedBy do
				table.insert(grantedBy, name)
			end
		elseif AccessStateUtils.isUnresolved(state) then
			anyUnresolved = true
		end
	end

	if #grantedBy > 0 then
		return AccessStateUtils.allowed(grantedBy)
	elseif anyUnresolved then
		return AccessStateUtils.unresolved()
	end

	for _, state in states do
		return state
	end

	return AccessStateUtils.disallowed(AccessStateUtils.Reasons.NOT_GRANTED)
end

--[=[
	The same fold over every fact present, for a feature whose fact list is not fixed when it is written.
	Safe now that states are always present -- it was not, when an unanswered fact vanished from the map.

	@param factState AccessFactState
	@return AccessState
]=]
function AccessStateUtils.fromAnyFact(factState: AccessFactState): AccessState
	local factNames = {}
	for factName in factState do
		table.insert(factNames, factName)
	end
	table.sort(factNames)

	return AccessStateUtils.fromFacts(factState, factNames)
end

return AccessStateUtils
