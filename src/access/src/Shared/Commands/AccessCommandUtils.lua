--!strict
--[=[
	Cmdr types and readout formatting for [AccessDataService].

	The formatting lives here, apart from the command that prints it, because the readout is the thing
	this package exists to make good -- somebody is complaining, and this is what tells you why. Pure
	functions over an [AccessFactReport], so the exact text is unit-tested rather than eyeballed once.

	@class AccessCommandUtils
]=]

local AccessCommandUtils = {}

--[=[
	The three things an override can be set to. `unresolved` is spelled out rather than left as an empty
	argument because forcing a fact to "nobody knows" is a deliberate thing to do, not a missing value.

	@prop OverrideValues { TRUE: string, FALSE: string, UNRESOLVED: string }
	@within AccessCommandUtils
]=]
AccessCommandUtils.ToggleValues = {
	ON = "on",
	OFF = "off",
}

AccessCommandUtils.OverrideValues = {
	TRUE = "true",
	FALSE = "false",
	UNRESOLVED = "unresolved",
}

local ABSTAINED = "abstained"
local DECIDED_MARKER = " <-- decided"
local SOURCE_WIDTH = 16

--[=[
	How a tri-state reads to a human. Never blank -- an empty column in a readout looks like a bug in the
	readout rather than the answer it actually is.

	@param value boolean?
	@return string
]=]
function AccessCommandUtils.describeValue(value: boolean?): string
	if value == true then
		return "true"
	elseif value == false then
		return "false"
	end

	return AccessCommandUtils.OverrideValues.UNRESOLVED
end

--[=[
	Turns the override argument back into the value it names.

	@param text string
	@return boolean?
]=]
function AccessCommandUtils.parseOverrideValue(text: string): boolean?
	if text == AccessCommandUtils.OverrideValues.TRUE then
		return true
	elseif text == AccessCommandUtils.OverrideValues.FALSE then
		return false
	end

	return nil
end

--[=[
	Attribution, rendered inline. Empty when a layer attached none, so the common case stays uncluttered.

	Answers the question a bare "true" cannot: *which* friend granted this, *which* gamepass was owned.

	@param metadata any?
	@return string
]=]
function AccessCommandUtils.describeMetadata(metadata: any?): string
	if metadata == nil then
		return ""
	elseif type(metadata) ~= "table" then
		return ` [{tostring(metadata)}]`
	end

	local parts = {}
	local keys = {}
	for key in metadata do
		table.insert(keys, tostring(key))
	end
	table.sort(keys)

	for _, key in keys do
		table.insert(parts, `{key}={tostring(metadata[key])}`)
	end

	if #parts == 0 then
		return ""
	end

	return ` [{table.concat(parts, " ")}]`
end

--[=[
	One fact and every layer under it, highest priority first, with the winner marked.

	Losing layers are printed rather than hidden. "Denied and the allowlist said false" and "denied and
	the allowlist never answered" are different problems, and only the full list tells them apart.

	@param report AccessFactReport
	@param indent string?
	@return string
]=]
function AccessCommandUtils.formatFactReport(report: any, indent: string?): string
	local pad = indent or ""
	local lines = {
		string.format(
			"%s%s = %s (%s)",
			pad,
			report.factName,
			AccessCommandUtils.describeValue(report.value),
			report.decidedBy or "nothing contributed"
		),
	}

	for _, layer in report.layers do
		table.insert(
			lines,
			string.format(
				"%s  %-" .. SOURCE_WIDTH .. "s p%-7d %-11s%s%s",
				pad,
				layer.source,
				layer.priority,
				if layer.contributes then AccessCommandUtils.describeValue(layer.value) else ABSTAINED,
				AccessCommandUtils.describeMetadata(layer.metadata),
				if layer.decided then DECIDED_MARKER else ""
			)
		)
	end

	return table.concat(lines, "\n")
end

--[=[
	A feature's verdict followed by every fact it read. The whole answer to a complaint in one block.

	@param report AccessFeatureReport
	@return string
]=]
function AccessCommandUtils.formatFeatureReport(report: any): string
	local state = report.state
	local verdict = if state.type == "allowed"
		then `allowed (granted by {table.concat(state.grantedBy, ", ")})`
		else `disallowed ({state.reason})`

	local lines = { `{report.featureName} = {verdict}` }

	local factNames = {}
	for factName in report.facts do
		table.insert(factNames, factName)
	end
	table.sort(factNames)

	if #factNames == 0 then
		table.insert(lines, "  (reads no facts)")
	end

	for _, factName in factNames do
		table.insert(lines, AccessCommandUtils.formatFactReport(report.facts[factName], "  "))
	end

	return table.concat(lines, "\n")
end

--[=[
	Every policy and whether it is running. A disabled policy is listed rather than hidden -- knowing a
	consequence exists but is switched off is most of the answer to "why did nothing happen".

	@param policies { { policyName: string, enabled: boolean, facts: { string } } }
	@return string
]=]
function AccessCommandUtils.formatPolicies(policies: { any }): string
	if #policies == 0 then
		return "  (none registered)"
	end

	local lines = {}
	for _, policy in policies do
		local reads = if #policy.facts > 0 then table.concat(policy.facts, ", ") else "nothing"
		table.insert(
			lines,
			string.format(
				"  %-" .. SOURCE_WIDTH .. "s %-9s reads %s",
				policy.policyName,
				if policy.enabled then "ENABLED" else "disabled",
				reads
			)
		)
	end

	return table.concat(lines, "\n")
end

--[=[
	Everything known about one player, in the order you actually read it: what the game concluded, then
	the facts those conclusions rest on. One block to paste into a bug report.

	@param featureReports { AccessFeatureReport }
	@param factReports { [string]: AccessFactReport }
	@return string
]=]
function AccessCommandUtils.formatPlayerState(
	featureReports: { any },
	factReports: { [string]: any },
	policies: { any }?
): string
	local lines = { "FEATURES" }

	if #featureReports == 0 then
		table.insert(lines, "  (none registered)")
	end

	for _, report in featureReports do
		local state = report.state
		local verdict = if state.type == "allowed"
			then `allowed (granted by {table.concat(state.grantedBy, ", ")})`
			else `disallowed ({state.reason})`

		table.insert(lines, `  {report.featureName} = {verdict}`)
	end

	table.insert(lines, "")
	table.insert(lines, "POLICIES")
	table.insert(lines, AccessCommandUtils.formatPolicies(policies or {}))

	table.insert(lines, "")
	table.insert(lines, "FACTS")

	local factNames = {}
	for factName in factReports do
		table.insert(factNames, factName)
	end
	table.sort(factNames)

	if #factNames == 0 then
		table.insert(lines, "  (none registered)")
	end

	for _, factName in factNames do
		table.insert(lines, AccessCommandUtils.formatFactReport(factReports[factName], "  "))
	end

	return table.concat(lines, "\n")
end

--[=[
	Registers the fact-name and override-value argument types. Called on both realms -- the client needs
	them for autocomplete, the server to validate.

	`getPolicyNames` is optional only as a fallback. Both realms register policies, so both realms should
	pass it -- without it the argument accepts whatever is typed and suggests nothing.

	@param cmdr any
	@param accessDataService AccessDataService
	@param getPolicyNames (() -> { string })?
]=]
function AccessCommandUtils.registerTypes(cmdr: any, accessDataService: any, getPolicyNames: (() -> { string })?): ()
	assert(accessDataService, "No accessDataService")
	assert(type(getPolicyNames) == "function" or getPolicyNames == nil, "Bad getPolicyNames")

	local factName = {
		Transform = function(text: string)
			return cmdr.Util.MakeFuzzyFinder(accessDataService:GetFactNames())(text)
		end,
		Validate = function(keys)
			return #keys > 0, "No fact registered by that name."
		end,
		Autocomplete = function(keys)
			return keys
		end,
		Parse = function(keys)
			return keys[1]
		end,
	}

	local featureName = {
		Transform = function(text: string)
			return cmdr.Util.MakeFuzzyFinder(accessDataService:GetFeatureNames())(text)
		end,
		Validate = function(keys)
			return #keys > 0, "No feature registered by that name."
		end,
		Autocomplete = function(keys)
			return keys
		end,
		Parse = function(keys)
			return keys[1]
		end,
	}

	cmdr.Registry:RegisterType("accessFactName", factName)
	cmdr.Registry:RegisterType("accessFactNames", cmdr.Util.MakeListableType(factName))
	cmdr.Registry:RegisterType("accessFeatureName", featureName)
	cmdr.Registry:RegisterType("accessPolicyName", {
		Transform = function(text: string)
			return cmdr.Util.MakeFuzzyFinder(if getPolicyNames then getPolicyNames() else { text })(text)
		end,
		Validate = function(keys)
			return #keys > 0, "No policy registered by that name."
		end,
		Autocomplete = function(keys)
			return keys
		end,
		Parse = function(keys)
			return keys[1]
		end,
	})
	cmdr.Registry:RegisterType(
		"accessToggle",
		cmdr.Util.MakeEnumType("accessToggle", {
			AccessCommandUtils.ToggleValues.ON,
			AccessCommandUtils.ToggleValues.OFF,
		})
	)
	-- Cmdr has no RegisterEnumType; an enum is a type object built by Util.MakeEnumType and registered
	-- like any other.
	cmdr.Registry:RegisterType(
		"accessOverrideValue",
		cmdr.Util.MakeEnumType("accessOverrideValue", {
			AccessCommandUtils.OverrideValues.TRUE,
			AccessCommandUtils.OverrideValues.FALSE,
			AccessCommandUtils.OverrideValues.UNRESOLVED,
		})
	)
end

return AccessCommandUtils
