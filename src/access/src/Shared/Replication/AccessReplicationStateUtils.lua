--!strict
--[=[
	Reading an [AccessReplicationState] out of what actually arrived, and asking the one question the
	combine rules turn on.

	@class AccessReplicationStateUtils
]=]

local require = require(script.Parent.loader).load(script)

local AccessReplicationState = require("AccessReplicationState")

local AccessReplicationStateUtils = {}

--[=[
	The state a replicated entry represents.

	No entry at all is `NOT_YET_ARRIVED`; an entry whose `value` is nil is the server saying it could not
	answer. Those are different, and telling them apart is the entire reason entries are boxed rather
	than stored as bare booleans.

	@param entry { value: boolean?, abstained: boolean? }?
	@return string
]=]
function AccessReplicationStateUtils.fromEntry(entry: { value: boolean?, abstained: boolean? }?): string
	-- Cast because SimpleEnum hands its members back as plain strings; the union is the contract callers
	-- see, and it is what makes a missed state a type error at the call site.
	if entry == nil then
		return AccessReplicationState.NOT_YET_ARRIVED :: any
	elseif entry.abstained then
		return AccessReplicationState.ABSTAINED :: any
	elseif entry.value == nil then
		return AccessReplicationState.UNRESOLVED :: any
	end

	return AccessReplicationState.RESOLVED :: any
end

--[=[
	Whether the server has said something that may override a local answer. False for both
	`NOT_YET_ARRIVED` and `ABSTAINED` -- silence and "I cannot answer either" both leave the local answer
	standing.

	@param state string
	@return boolean
]=]
function AccessReplicationStateUtils.hasAnswer(state: string): boolean
	return state == AccessReplicationState.RESOLVED or state == AccessReplicationState.UNRESOLVED
end

--[=[
	@param value any
	@return boolean
]=]
function AccessReplicationStateUtils.isReplicationState(value: any): boolean
	for _, state in AccessReplicationState:GetValues() do
		if state == value then
			return true
		end
	end

	return false
end

return AccessReplicationStateUtils
