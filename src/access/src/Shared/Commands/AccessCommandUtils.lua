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

--[=[
	Which realm a readout should come from. `both` is the one worth reaching for: the server and the
	client disagreeing about a fact is the failure this package exists to make visible, and it is
	invisible from either side alone.

	@prop RealmValues { SERVER: string, CLIENT: string, BOTH: string }
	@within AccessCommandUtils
]=]
AccessCommandUtils.RealmValues = {
	SERVER = "server",
	CLIENT = "client",
	BOTH = "both",
}

AccessCommandUtils.OverrideValues = {
	TRUE = "true",
	FALSE = "false",
	UNRESOLVED = "unresolved",
}

local DECIDED_MARKER = " <-- decided"
local SOURCE_WIDTH = 16
local NAMED_LIMIT = 4

--[[
	GOTCHA: keeps the LAST emission, not the first. A fact opens on unresolved before anything is looked
	up, so taking the first would print "unresolved" for everything however well resolved it is.
]]
local function readOnce(observable: any): any
	local captured = nil
	local subscription = observable:Subscribe(function(value)
		captured = value
	end)
	subscription:Destroy()

	return captured
end

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
		string.format("%s%s = %s (%s)", pad, report.factName, report.state, report.decidedBy or "nothing contributed"),
	}

	for _, layer in report.layers do
		table.insert(
			lines,
			string.format(
				"%s  %-" .. SOURCE_WIDTH .. "s p%-7d %-11s%s%s",
				pad,
				layer.source,
				layer.priority,
				layer.state,
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
	@param subject any -- what it was evaluated against, named on the verdict line
	@return string
]=]
function AccessCommandUtils.formatFeatureReport(report: any, subject: any?): string
	local state = report.state
	local verdict = if state.type == "allowed"
		then `allowed (granted by {table.concat(state.grantedBy, ", ")})`
		else `disallowed ({state.reason})`

	local lines = { `{report.featureName}{AccessCommandUtils.describeSubject(subject)} = {verdict}` }

	for _, line in AccessCommandUtils.formatContext(report.context) do
		table.insert(lines, line)
	end

	for _, line in AccessCommandUtils.formatFeatureInputs(report.features) do
		table.insert(lines, line)
	end

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
	A feature's non-fact inputs, one per line, sorted. Empty when the feature declared none -- a feature
	with no context should read exactly as it did before there was such a thing.

	@param context { [string]: any }?
	@return { string }
]=]
function AccessCommandUtils.formatContext(context: { [string]: any }?): { string }
	if context == nil then
		return {}
	end

	local names = {}
	for name in context do
		table.insert(names, name)
	end
	table.sort(names)

	local lines = {}
	for _, name in names do
		table.insert(lines, string.format("  %-" .. SOURCE_WIDTH .. "s %s", name, tostring(context[name])))
	end

	return lines
end

--[=[
	The verdicts this feature inherited from other features, one per line, sorted.

	Named and reasoned rather than reduced to true/false: "refused because bought access is switched off"
	and "refused because they do not own it" are different answers to the person complaining, and a
	boolean loses both.

	@param features { [string]: AccessState }?
	@return { string }
]=]
function AccessCommandUtils.formatFeatureInputs(features: { [string]: any }?): { string }
	if features == nil then
		return {}
	end

	local names = {}
	for name in features do
		table.insert(names, name)
	end
	table.sort(names)

	local lines = {}
	for _, name in names do
		local state = features[name]
		local verdict = if state.type == "allowed"
			then `allowed (granted by {table.concat(state.grantedBy, ", ")})`
			else `disallowed ({state.reason})`
		table.insert(lines, string.format("  %-" .. SOURCE_WIDTH .. "s %s", name, verdict))
	end

	return lines
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
	policies: { any }?,
	featureNamesNeedingSubject: { string }?
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

	for _, featureName in (featureNamesNeedingSubject or {}) :: { string } do
		-- Listed rather than answered, and pointed somewhere that can answer it.
		table.insert(lines, `  {featureName} = needs a subject: access-feature <player> {featureName} <subject>`)
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
	How a list of names reads back in a confirmation. Names them while there are few enough to check at a
	glance, and counts them once naming them would be a wall -- which is exactly what `*` produces.

	Sorted, because Cmdr builds a list argument by iterating its dedupe table: the order it hands back is
	hash order, not the order anybody typed.

	@param names { string }
	@param noun string -- plural, for the count and empty forms: "facts", "policies"
	@return string
]=]
function AccessCommandUtils.describeNameList(names: { string }, noun: string): string
	if #names == 0 then
		return `no {noun}`
	elseif #names > NAMED_LIMIT then
		return `{#names} {noun}`
	end

	local sorted = table.clone(names)
	table.sort(sorted)

	return table.concat(sorted, ", ")
end

--[=[
	Turns what somebody typed into the subject a per-thing feature is evaluated against.

	Numeric text becomes a number, because the subjects that actually get typed are ids -- a world index, a
	chapter -- and a feature comparing `subject == 3` would silently deny for `"3"`. Anything else is
	passed through as the string it was. Empty means no subject.

	@param text string?
	@return any
]=]
function AccessCommandUtils.parseSubject(text: string?): any
	if text == nil or text == "" then
		return nil
	end

	return tonumber(text) or text
end

--[=[
	How a subject reads on a verdict line. Empty when there is none, because most features never take one
	and "(no subject)" on every line would read as a missing input rather than as a feature that has no
	such input. Where the absence does matter -- a whole-player dump, where a per-thing gate is being shown
	in the one form nobody needs -- [AccessCommandUtils.formatPlayerState] says so once instead.

	@param subject any
	@return string
]=]
function AccessCommandUtils.describeSubject(subject: any): string
	if subject == nil then
		return ""
	end

	return ` (subject {tostring(subject)})`
end

--[=[
	Everything a readout needs about one player, gathered from whichever realm this runs on.

	Shared rather than written twice, because the whole value of showing the client's view next to the
	server's is that a difference between them is a real difference and not two formatters disagreeing.

	The result is plain tables so it can be sent over remoting for exactly that comparison.

	@param accessDataService AccessDataService
	@param accessPolicyService AccessPolicyService
	@param player Player
	@return { featureReports: { AccessFeatureReport }, factReports: { [string]: AccessFactReport }, policies: { any } }
]=]
function AccessCommandUtils.collectPlayerState(accessDataService: any, accessPolicyService: any, player: Player): any
	assert(accessDataService, "No accessDataService")
	assert(player, "No player")

	local featureReports = {}
	local needSubject = {}
	for _, featureName in accessDataService:GetFeatureNames() do
		local feature = accessDataService:GetFeature(featureName)
		if feature and feature:RequiresSubject() then
			-- Named, not evaluated. A dump cannot pass a subject, and a per-thing gate answered with none is
			-- a verdict for a question nobody asked -- worse than saying the question needs an argument.
			table.insert(needSubject, featureName)
		elseif feature then
			local report = readOnce(accessDataService:ObserveFeatureReport(player, feature))
			if report then
				table.insert(featureReports, report)
			end
		end
	end

	local policies = {}
	if accessPolicyService then
		for _, policyName in accessPolicyService:GetPolicyNames() do
			local policy = accessPolicyService:GetPolicy(policyName)
			if policy then
				table.insert(policies, {
					policyName = policyName,
					enabled = accessPolicyService:IsPolicyEnabled(policyName),
					facts = policy:GetFactNames(),
				})
			end
		end
	end

	return {
		featureReports = featureReports,
		featureNamesNeedingSubject = needSubject,
		factReports = readOnce(accessDataService:ObserveFactReports(player)) or {},
		policies = policies,
	}
end

--[=[
	Renders what [AccessCommandUtils.collectPlayerState] gathered.

	@param collected any
	@return string
]=]
function AccessCommandUtils.formatCollectedPlayerState(collected: any): string
	return AccessCommandUtils.formatPlayerState(
		collected.featureReports,
		collected.factReports,
		collected.policies,
		collected.featureNamesNeedingSubject
	)
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
			-- An empty search matches everything, which is what makes `*` expand: Cmdr builds the wildcard
			-- from this type's autocomplete over an empty segment.
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

	local policyName = {
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
	}

	cmdr.Registry:RegisterType("accessFactName", factName)
	-- Listable, which is what buys `access-override . * false`: Cmdr only expands `*` and `**` for a type
	-- that says it takes a list. `all` is the spelled-out alias, the same one the built-in players type
	-- offers, because a wildcard is worth being able to type deliberately.
	cmdr.Registry:RegisterType(
		"accessFactNames",
		cmdr.Util.MakeListableType(factName, {
			ArgumentOperatorAliases = {
				all = "*",
			},
		})
	)
	cmdr.Registry:RegisterType("accessFeatureName", featureName)
	cmdr.Registry:RegisterType("accessPolicyName", policyName)
	-- Same as the facts, and for the same reason: `access-policy * off` is how somebody switches every
	-- consequence off to see the game without them.
	cmdr.Registry:RegisterType(
		"accessPolicyNames",
		cmdr.Util.MakeListableType(policyName, {
			ArgumentOperatorAliases = {
				all = "*",
			},
		})
	)
	cmdr.Registry:RegisterType(
		"accessToggle",
		cmdr.Util.MakeEnumType("accessToggle", {
			AccessCommandUtils.ToggleValues.ON,
			AccessCommandUtils.ToggleValues.OFF,
		})
	)
	cmdr.Registry:RegisterType(
		"accessRealm",
		cmdr.Util.MakeEnumType("accessRealm", {
			AccessCommandUtils.RealmValues.SERVER,
			AccessCommandUtils.RealmValues.CLIENT,
			AccessCommandUtils.RealmValues.BOTH,
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
