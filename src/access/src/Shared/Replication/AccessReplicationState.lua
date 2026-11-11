--!strict
--[=[
	What this realm has been told about a fact, as four distinct states rather than a boolean and a
	guess. Helpers live in [AccessReplicationStateUtils].

	Three of these look like "false" if you flatten them, and each needs a different response:

	* **NOT_YET_ARRIVED** -- the server has not spoken. Never overrides; the local answer stands.
	* **ABSTAINED** -- the server has no layer for this fact either. Nobody anywhere can answer it.
	* **UNRESOLVED** -- the server tried and could not answer yet. A real answer, so it stops a local
	  fall-through.
	* **RESOLVED** -- the server has an answer, carried alongside in `value`.

	Collapsing these is how a chapter picker ends up empty forever: "has not arrived" and "cannot be
	answered" render identically while meaning opposite things about whether waiting will help.

	@class AccessReplicationState
]=]

local require = require(script.Parent.loader).load(script)

local SimpleEnum = require("SimpleEnum")

export type AccessReplicationState = "notYetArrived" | "abstained" | "unresolved" | "resolved"

return SimpleEnum.new({
	NOT_YET_ARRIVED = "notYetArrived" :: "notYetArrived",
	ABSTAINED = "abstained" :: "abstained",
	UNRESOLVED = "unresolved" :: "unresolved",
	RESOLVED = "resolved" :: "resolved",
})
