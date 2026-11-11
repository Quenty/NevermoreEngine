--!strict
--[=[
	How a fact's server answer combines with the one the client worked out for itself.

	The server's answer **always replicates** -- that part is not configurable, because a client that
	silently never hears is the failure nobody can debug. What a fact chooses is what the client should
	*do* with it, and there are only four sensible answers, so they are named rather than left to a
	predicate somebody has to read.

	@class AccessFactServerOverrideBehavior
]=]

local require = require(script.Parent.loader).load(script)

local AccessReplicationStateUtils = require("AccessReplicationStateUtils")

local AccessFactServerOverrideBehavior = {
	--[=[
		The server decides, full stop. For anything the client cannot see and must not guess about.
		@prop SERVER_OVERRIDE_ALL string
		@within AccessFactServerOverrideBehavior
	]=]
	SERVER_OVERRIDE_ALL = "serverOverrideAll",

	--[=[
		The client's own answer stands; the server's is carried for readouts only. For facts a client
		resolves perfectly well on its own, where replication exists so `access-facts` can show both.
		@prop SERVER_OVERRIDE_NONE string
		@within AccessFactServerOverrideBehavior
	]=]
	SERVER_OVERRIDE_NONE = "serverOverrideNone",

	--[=[
		The server may open a gate but never close one. **The default.**

		A fact the client cannot resolve reads unresolved locally, and the server turning that into a yes
		is the whole reason replication exists. The converse -- letting a late or missing server value take
		away access the client had already worked out -- is the failure mode this package exists to avoid,
		so it is off by default.
		@prop SERVER_OVERRIDE_ON_ALLOW_ONLY string
		@within AccessFactServerOverrideBehavior
	]=]
	SERVER_OVERRIDE_ON_ALLOW_ONLY = "serverOverrideOnAllowOnly",

	--[=[
		The server may close a gate but never open one. For a fact where the client is optimistic and the
		server is the one holding the bad news -- a ban, a revoked entitlement.
		@prop SERVER_OVERRIDE_ON_DISALLOW_ONLY string
		@within AccessFactServerOverrideBehavior
	]=]
	SERVER_OVERRIDE_ON_DISALLOW_ONLY = "serverOverrideOnDisallowOnly",
}

--[=[
	The behavior a fact gets when it does not choose one.

	@prop DEFAULT string
	@within AccessFactServerOverrideBehavior
]=]
AccessFactServerOverrideBehavior.DEFAULT = AccessFactServerOverrideBehavior.SERVER_OVERRIDE_ON_ALLOW_ONLY

--[=[
	@param value any
	@return boolean
]=]
function AccessFactServerOverrideBehavior.isBehavior(value: any): boolean
	for _, behavior in AccessFactServerOverrideBehavior do
		if behavior == value then
			return true
		end
	end

	return false
end

--[=[
	Combines the two answers. Pure, and the only place the rule lives.

	Two rules come before the behavior, and both matter more than it does:

	1. Unless the server has actually said something -- [AccessReplicationState].hasAnswer -- nothing is
	   overridden. `NOT_YET_ARRIVED` and `ABSTAINED` both leave the local answer alone, and taking the
	   state rather than inspecting a value is what keeps "has not arrived" from being confused with
	   "arrived saying no".
	2. If this realm has no answer of its own, the server's simply **is** the answer. A behavior governs
	   *overriding a local answer*; with none to override there is nothing to protect. Without this a
	   fact the client cannot compute -- a receipt in a server-only DataStore -- would sit unresolved
	   forever under the default, and every feature reading it would never settle. That is not a wrong
	   answer on screen, it is a screen that never fills in.

	@param localValue boolean? -- what this realm worked out
	@param serverValue boolean? -- what the server replicated
	@param replicationState string -- see AccessReplicationState
	@param behavior string?
	@return boolean?
]=]
function AccessFactServerOverrideBehavior.combine(
	localValue: boolean?,
	serverValue: boolean?,
	replicationState: string,
	behavior: string?
): boolean?
	if not AccessReplicationStateUtils.hasAnswer(replicationState) then
		return localValue
	end

	if localValue == nil then
		return serverValue
	end

	local resolved = behavior or AccessFactServerOverrideBehavior.DEFAULT

	if resolved == AccessFactServerOverrideBehavior.SERVER_OVERRIDE_NONE then
		return localValue
	elseif resolved == AccessFactServerOverrideBehavior.SERVER_OVERRIDE_ALL then
		return serverValue
	elseif resolved == AccessFactServerOverrideBehavior.SERVER_OVERRIDE_ON_ALLOW_ONLY then
		return if serverValue == true then true else localValue
	elseif resolved == AccessFactServerOverrideBehavior.SERVER_OVERRIDE_ON_DISALLOW_ONLY then
		return if serverValue == false then false else localValue
	end

	error(`[AccessFactServerOverrideBehavior] - Unknown behavior {tostring(behavior)}`)
end

return AccessFactServerOverrideBehavior
