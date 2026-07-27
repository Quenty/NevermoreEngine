--!strict
--[=[
	Where a fact layer sits when several answer the same fact.

	Several mechanisms can legitimately answer one question -- a group rank and an allowlist both say
	whether someone is staff, a console override says so louder than either. Rather than let registration
	order decide, every layer declares a priority and the highest one that has something to say wins.

	Numbers, not an enum, so a game can sit between two of these without the package having to know about
	it. Two layers registering at the same priority for the same fact is an error rather than a coin toss.

	@class AccessFactPriority
]=]

local AccessFactPriority = {
	--[=[
		The package's own built-in facts. Lowest, so anything a game registers outranks them.
		@prop BUILT_IN number
		@within AccessFactPriority
	]=]
	BUILT_IN = -100,

	--[=[
		Where a fact lands when it does not say. Most facts.
		@prop DEFAULT number
		@within AccessFactPriority
	]=]
	DEFAULT = 0,

	--[=[
		A fact that should beat the ordinary answer -- a live event switch, a staff allowlist.
		@prop ELEVATED number
		@within AccessFactPriority
	]=]
	ELEVATED = 100,

	--[=[
		Console and test overrides. Deliberately far above anything a game will register, so an override
		always wins and never has to be reconciled against whatever a game added later.
		@prop OVERRIDE number
		@within AccessFactPriority
	]=]
	OVERRIDE = 10000,
}

return AccessFactPriority
