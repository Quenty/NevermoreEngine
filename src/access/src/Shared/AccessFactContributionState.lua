--!strict
--[=[
	What a fact layer said, named rather than encoded in a boolean and a nil.

	`nil` used to carry two of these at once, which is the root of a whole family of bugs: a Lua table
	cannot hold nil, so an unresolved fact simply vanished from any map it was put in, and
	[Rx.combineLatest] dropped it on the floor. Every layer now says which of four things it means.

	* **ALLOW** -- yes.
	* **DENY** -- no.
	* **UNRESOLVED** -- I tried and cannot say yet. An answer, not a silence.
	* **ABSTAIN** -- not my question. Skip me entirely and ask the next layer.

	Helpers live in [AccessFactContributionStateUtils].

	@class AccessFactContributionState
]=]

local require = require(script.Parent.loader).load(script)

local SimpleEnum = require("SimpleEnum")

export type AccessFactContributionState = "allow" | "deny" | "unresolved" | "abstain"

return SimpleEnum.new({
	ALLOW = "allow" :: "allow",
	DENY = "deny" :: "deny",
	UNRESOLVED = "unresolved" :: "unresolved",
	ABSTAIN = "abstain" :: "abstain",
})
