--!strict
--[=[
	Moving between an [AccessFactContributionState] and the plain values authors write.

	Authoring stays cheap -- a resolver may still return `true`, `false`, or an observable of `boolean?`
	-- and the boundary names what arrived. What is no longer possible is an unlabelled nil reaching the
	merge, where it used to mean two different things depending on where you looked.

	@class AccessFactContributionStateUtils
]=]

local require = require(script.Parent.loader).load(script)

local AccessFactContributionState = require("AccessFactContributionState")

local AccessFactContributionStateUtils = {}

--[=[
	The state a plain authored value means. `nil` becomes UNRESOLVED, which is the only reading that was
	ever intended -- a source that has not answered yet is saying "I cannot say", not "skip me".

	@param value boolean?
	@return string
]=]
function AccessFactContributionStateUtils.fromValue(value: boolean?): string
	if value == true then
		return AccessFactContributionState.ALLOW
	elseif value == false then
		return AccessFactContributionState.DENY
	end

	return AccessFactContributionState.UNRESOLVED
end

--[=[
	The boolean a state carries, for the callers that still work in booleans. ALLOW and DENY only;
	anything else is nil, because neither UNRESOLVED nor ABSTAIN is a yes-or-no.

	@param state string
	@return boolean?
]=]
function AccessFactContributionStateUtils.toValue(state: string): boolean?
	if state == AccessFactContributionState.ALLOW then
		return true
	elseif state == AccessFactContributionState.DENY then
		return false
	end

	return nil
end

--[=[
	Whether a layer said anything at all. False only for ABSTAIN -- the merge skips those and asks the
	next layer down.

	@param state string
	@return boolean
]=]
function AccessFactContributionStateUtils.contributes(state: string): boolean
	return state ~= AccessFactContributionState.ABSTAIN
end

--[=[
	Whether a state is a definite yes or no, as opposed to a non-answer.

	@param state string
	@return boolean
]=]
function AccessFactContributionStateUtils.isDefinite(state: string): boolean
	return state == AccessFactContributionState.ALLOW or state == AccessFactContributionState.DENY
end

--[=[
	@param value any
	@return boolean
]=]
function AccessFactContributionStateUtils.isContributionState(value: any): boolean
	for _, state in AccessFactContributionState:GetValues() do
		if state == value then
			return true
		end
	end

	return false
end

return AccessFactContributionStateUtils
