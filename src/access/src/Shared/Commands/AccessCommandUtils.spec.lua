--!strict
--[[
	@class AccessCommandUtils.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessCommandUtils = require("AccessCommandUtils")
local AccessFactContributionState = require("AccessFactContributionState")
local AccessFactPriority = require("AccessFactPriority")
local AccessStateUtils = require("AccessStateUtils")
local Jest = require("Jest")
local Rx = require("Rx")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- These are pure functions over reports; the player is only ever passed through to the observables.
local PLAYER = Instance.new("Folder") :: any

local function layer(source: string, priority: number, contributes: boolean, value: boolean?, decided: boolean)
	return {
		source = source,
		priority = priority,
		state = if not contributes
			then AccessFactContributionState.ABSTAIN
			elseif value == true then AccessFactContributionState.ALLOW
			elseif value == false then AccessFactContributionState.DENY
			else AccessFactContributionState.UNRESOLVED,
		contributes = contributes,
		value = value,
		decided = decided,
	}
end

local function staffReport()
	return {
		factName = "isStaff",
		state = AccessFactContributionState.ALLOW,
		value = true,
		decidedBy = "allowlist",
		layers = {
			layer("override", AccessFactPriority.OVERRIDE, false, nil, false),
			layer("allowlist", AccessFactPriority.ELEVATED, true, true, true),
			layer("groupRank", AccessFactPriority.DEFAULT, true, false, false),
		},
	}
end

describe("AccessCommandUtils.describeValue", function()
	it("never renders a tri-state as blank", function()
		-- An empty column reads as a broken readout rather than as the answer it actually is.
		expect(AccessCommandUtils.describeValue(true)).toEqual("true")
		expect(AccessCommandUtils.describeValue(false)).toEqual("false")
		expect(AccessCommandUtils.describeValue(nil)).toEqual("unresolved")
	end)
end)

describe("AccessCommandUtils.parseOverrideValue", function()
	it("round-trips every value the console offers", function()
		expect(AccessCommandUtils.parseOverrideValue("true")).toEqual(true)
		expect(AccessCommandUtils.parseOverrideValue("false")).toEqual(false)
		expect(AccessCommandUtils.parseOverrideValue("unresolved")).toEqual(nil)
	end)
end)

describe("AccessCommandUtils.formatFactReport", function()
	it("leads with the answer and who decided it", function()
		local lines = string.split(AccessCommandUtils.formatFactReport(staffReport()), "\n")

		expect(lines[1]).toEqual("isStaff = allow (allowlist)")
	end)

	it("marks exactly one layer as the decider", function()
		local text = AccessCommandUtils.formatFactReport(staffReport())
		local _, count = string.gsub(text, "decided", "")

		expect(count).toEqual(1)
	end)

	it("keeps the losing layers visible", function()
		-- "denied and the allowlist said false" and "denied and the allowlist never answered" are
		-- different problems, and only the full list tells them apart.
		local text = AccessCommandUtils.formatFactReport(staffReport())

		expect(string.find(text, "groupRank") ~= nil).toEqual(true)
		expect(string.find(text, AccessFactContributionState.DENY) ~= nil).toEqual(true)
	end)

	it("says a layer abstained rather than showing it as an answer", function()
		local text = AccessCommandUtils.formatFactReport(staffReport())

		expect(string.find(text, AccessFactContributionState.ABSTAIN) ~= nil).toEqual(true)
	end)

	it("says so plainly when nothing contributed", function()
		local text = AccessCommandUtils.formatFactReport({
			factName = "isStaff",
			state = AccessFactContributionState.UNRESOLVED,
			value = nil,
			decidedBy = nil,
			layers = {},
		})

		expect(text).toEqual("isStaff = unresolved (nothing contributed)")
	end)

	it("indents every line it emits, not just the first", function()
		local text = AccessCommandUtils.formatFactReport(staffReport(), "  ")

		for _, line in string.split(text, "\n") do
			expect(string.sub(line, 1, 2)).toEqual("  ")
		end
	end)
end)

describe("AccessCommandUtils.formatFeatureReport", function()
	it("names the facts that granted an allowed verdict", function()
		local text = AccessCommandUtils.formatFeatureReport({
			featureName = "chapters",
			state = AccessStateUtils.allowed({ "isStaff" }),
			facts = { isStaff = staffReport() },
		})

		expect(string.split(text, "\n")[1]).toEqual("chapters = allowed (granted by isStaff)")
	end)

	it("gives the reason for a denial", function()
		local text = AccessCommandUtils.formatFeatureReport({
			featureName = "chapters",
			state = AccessStateUtils.unresolved(),
			facts = {},
		})

		expect(string.split(text, "\n")[1]).toEqual("chapters = disallowed (unresolved)")
	end)

	it("follows the verdict with every fact it read", function()
		local text = AccessCommandUtils.formatFeatureReport({
			featureName = "chapters",
			state = AccessStateUtils.allowed({ "isStaff" }),
			facts = { isStaff = staffReport() },
		})

		expect(string.find(text, "isStaff = " .. AccessFactContributionState.ALLOW) ~= nil).toEqual(true)
		expect(string.find(text, "groupRank") ~= nil).toEqual(true)
	end)

	it("says so when a feature reads no facts at all", function()
		local text = AccessCommandUtils.formatFeatureReport({
			featureName = "hub",
			state = AccessStateUtils.allowed(),
			facts = {},
		})

		expect(string.find(text, "reads no facts") ~= nil).toEqual(true)
	end)
end)

describe("AccessCommandUtils.formatPlayerState", function()
	it("leads with what the game concluded, then what it rests on", function()
		local text = AccessCommandUtils.formatPlayerState({
			{ featureName = "chapters", state = AccessStateUtils.allowed({ "isStaff" }), facts = {} },
		}, { isStaff = staffReport() })

		local featuresAt = string.find(text, "FEATURES")
		local factsAt = string.find(text, "FACTS")

		expect(featuresAt ~= nil).toEqual(true)
		expect((factsAt :: any) > (featuresAt :: any)).toEqual(true)
	end)

	it("includes the layer breakdown, not just the answers", function()
		local text = AccessCommandUtils.formatPlayerState({}, { isStaff = staffReport() })

		expect(string.find(text, "groupRank") ~= nil).toEqual(true)
		expect(string.find(text, "decided") ~= nil).toEqual(true)
	end)

	it("names a per-thing gate as needing a subject instead of answering it", function()
		-- access-state cannot pass a subject, and a verdict for a question nobody asked is worse than
		-- saying the question takes an argument. So it is listed, and pointed at the command that can.
		local text = AccessCommandUtils.formatPlayerState({}, {}, nil, { "canEnterWorld" })

		expect(string.find(text, "canEnterWorld = needs a subject") ~= nil).toEqual(true)
		expect(string.find(text, "access%-feature") ~= nil).toEqual(true)
	end)

	it("says so plainly when there is nothing registered", function()
		-- Features, policies and facts each say it, rather than a section silently vanishing.
		local text = AccessCommandUtils.formatPlayerState({}, {})

		local _, count = string.gsub(text, "none registered", "")
		expect(count).toEqual(3)
	end)

	it("lists policies between what was concluded and what it rests on", function()
		local text = AccessCommandUtils.formatPlayerState({}, {}, {
			{ policyName = "kickOnNonAdmin", enabled = false, facts = { "playerIsAdmin" } },
		})

		expect(string.find(text, "kickOnNonAdmin") ~= nil).toEqual(true)
		expect((string.find(text, "POLICIES") :: any) < (string.find(text, "FACTS") :: any)).toEqual(true)
	end)
end)

describe("AccessCommandUtils.formatPolicies", function()
	it("shows a disabled policy rather than hiding it", function()
		-- Knowing a consequence exists but is switched off is most of the answer to "why did nothing
		-- happen".
		local text = AccessCommandUtils.formatPolicies({
			{ policyName = "kickOnNonAdmin", enabled = false, facts = { "playerIsAdmin" } },
		})

		expect(string.find(text, "kickOnNonAdmin") ~= nil).toEqual(true)
		expect(string.find(text, "disabled") ~= nil).toEqual(true)
	end)

	it("makes an enabled policy stand out from a disabled one", function()
		local text = AccessCommandUtils.formatPolicies({
			{ policyName = "kickOnNonAdmin", enabled = true, facts = { "playerIsAdmin" } },
		})

		expect(string.find(text, "ENABLED") ~= nil).toEqual(true)
	end)

	it("names what each policy reads", function()
		local text = AccessCommandUtils.formatPolicies({
			{ policyName = "kickOnNonAdmin", enabled = true, facts = { "playerIsAdmin" } },
		})

		expect(string.find(text, "reads playerIsAdmin") ~= nil).toEqual(true)
	end)

	it("says a policy that reads nothing reads nothing", function()
		local text = AccessCommandUtils.formatPolicies({
			{ policyName = "always", enabled = false, facts = {} },
		})

		expect(string.find(text, "reads nothing") ~= nil).toEqual(true)
	end)
end)

-- A Cmdr stand-in that errors on anything Cmdr does not actually have. registerTypes is otherwise
-- unreachable from a headless test -- PromiseCmdr never resolves without a real Cmdr -- which is exactly
-- how a call to a nonexistent Registry method reached a playtest.
local function strictCmdr()
	local registered = {}

	local util = setmetatable({
		-- Narrows, rather than handing back the whole list whatever it was given. A finder that ignores its
		-- argument makes "resolves the name you typed" pass on any list of one, and pass on a longer one
		-- purely by what happens to be first.
		MakeFuzzyFinder = function(list: { string })
			return function(text: string)
				if text == "" then
					return list
				end

				local matches = {}
				for _, name in list do
					if string.find(name, text, 1, true) then
						table.insert(matches, name)
					end
				end

				return matches
			end
		end,
		-- Mirrors the real one closely enough to matter: it marks the type Listable (the flag Cmdr gates `*`
		-- expansion on), wraps Parse to return a list, and merges the override table.
		MakeListableType = function(typeObject: any, override: any?)
			local listable = table.clone(typeObject)
			listable.Listable = true
			listable.Parse = function(...)
				return { typeObject.Parse(...) }
			end

			for key, value in override or {} do
				listable[key] = value
			end

			return listable
		end,
		MakeEnumType = function(_name: string, values: { string })
			return { values = values }
		end,
	}, {
		__index = function(_self, key)
			error(`Cmdr.Util has no member {tostring(key)}`)
		end,
	})

	local registry = setmetatable({
		RegisterType = function(_self, name: string, typeObject: any)
			registered[name] = typeObject
		end,
	}, {
		__index = function(_self, key)
			error(`Cmdr.Registry has no method {tostring(key)}`)
		end,
	})

	return { Registry = registry, Util = util }, registered
end

local function fakeAccessDataService()
	return {
		GetFactNames = function()
			return { "playerIsAdmin" }
		end,
		GetFeatureNames = function()
			return { "chapters" }
		end,
	}
end

describe("AccessCommandUtils.registerTypes", function()
	it("only touches Cmdr APIs that exist", function()
		local cmdr, _registered = strictCmdr()

		expect(function()
			AccessCommandUtils.registerTypes(cmdr, fakeAccessDataService(), function()
				return { "kick-on-non-admin" }
			end)
		end).never.toThrow()
	end)

	it("registers every argument type it offers", function()
		local cmdr, registered = strictCmdr()
		AccessCommandUtils.registerTypes(cmdr, fakeAccessDataService(), function()
			return { "kick-on-non-admin" }
		end)

		for _, name in
			{
				"accessFactName",
				"accessFactNames",
				"accessFeatureName",
				"accessPolicyName",
				"accessPolicyNames",
				"accessOverrideValue",
				"accessRealm",
				"accessToggle",
			}
		do
			expect(registered[name]).never.toEqual(nil)
		end
	end)

	it("works without a policy-name source, which is how the client registers", function()
		local cmdr, registered = strictCmdr()

		expect(function()
			AccessCommandUtils.registerTypes(cmdr, fakeAccessDataService())
		end).never.toThrow()
		expect(registered.accessPolicyName).never.toEqual(nil)
	end)

	it("rejects a bad policy-name source rather than failing later inside Cmdr", function()
		local cmdr = strictCmdr()

		expect(function()
			AccessCommandUtils.registerTypes(cmdr, fakeAccessDataService(), "not a function" :: any)
		end).toThrow("Bad getPolicyNames")
	end)
end)

describe("AccessCommandUtils.parseSubject", function()
	it("turns typed digits into a number, which is what a subject usually is", function()
		-- A world index or a chapter compared with `subject == 3` would silently deny for "3", and a silent
		-- denial in a debugging tool is worse than no tool.
		expect(AccessCommandUtils.parseSubject("3")).toEqual(3)
	end)

	it("passes anything else through as typed", function()
		expect(AccessCommandUtils.parseSubject("blueEgg")).toEqual("blueEgg")
	end)

	it("reads a missing argument as no subject at all", function()
		expect(AccessCommandUtils.parseSubject("")).toEqual(nil)
		expect(AccessCommandUtils.parseSubject(nil)).toEqual(nil)
	end)
end)

describe("AccessCommandUtils.describeSubject", function()
	it("names the subject a verdict was reached against", function()
		expect(AccessCommandUtils.describeSubject(3)).toEqual(" (subject 3)")
	end)

	it("says nothing when there is none, so a feature that takes no subject reads clean", function()
		expect(AccessCommandUtils.describeSubject(nil)).toEqual("")
	end)

	it("puts the subject on the verdict line, not after the facts", function()
		local text = AccessCommandUtils.formatFeatureReport({
			featureName = "canEnterWorld",
			state = AccessStateUtils.allowed({ "isStaff" }),
			facts = { isStaff = staffReport() },
		}, 3)

		expect(string.split(text, "\n")[1]).toEqual("canEnterWorld (subject 3) = allowed (granted by isStaff)")
	end)
end)

describe("overriding every fact at once", function()
	--[[
		`access-override . * false` is how somebody shuts the whole thing down to see what breaks. Cmdr
		builds that expansion itself, but only for a type that says it is Listable and whose autocomplete
		over an empty segment returns everything -- so those are what is worth asserting here.
	]]
	local function factNamesType()
		local cmdr, registered = strictCmdr()
		AccessCommandUtils.registerTypes(cmdr, fakeAccessDataService())
		return registered.accessFactNames
	end

	it("is listable, which is the only reason * expands at all", function()
		expect(factNamesType().Listable).toEqual(true)
	end)

	it("matches every fact on an empty segment, which is what * expands to", function()
		local factType = factNamesType()

		expect(factType.Autocomplete(factType.Transform(""))).toEqual({ "playerIsAdmin" })
	end)

	it("still resolves one typed name", function()
		local factType = factNamesType()

		expect(factType.Parse(factType.Transform("playerIsAdmin"))).toEqual({ "playerIsAdmin" })
	end)

	it("offers `all` as the spelled-out wildcard", function()
		expect(factNamesType().ArgumentOperatorAliases.all).toEqual("*")
	end)
end)

describe("toggling every policy at once", function()
	--[[
		`access-policy * off` is how somebody sees the game with every consequence switched off. Asserted
		separately from the fact list because the two types are built from different name sources, and only
		the policy one is optional -- a client that registers without it gets a type that suggests nothing.
	]]
	local function policyNamesType()
		local cmdr, registered = strictCmdr()
		AccessCommandUtils.registerTypes(cmdr, fakeAccessDataService(), function()
			return { "kick-on-non-admin", "watch-shop" }
		end)
		return registered.accessPolicyNames
	end

	it("is listable, which is the only reason * expands at all", function()
		expect(policyNamesType().Listable).toEqual(true)
	end)

	it("matches every policy on an empty segment, which is what * expands to", function()
		local policyType = policyNamesType()

		expect(policyType.Autocomplete(policyType.Transform(""))).toEqual({ "kick-on-non-admin", "watch-shop" })
	end)

	it("still resolves one typed name", function()
		local policyType = policyNamesType()

		expect(policyType.Parse(policyType.Transform("kick-on-non-admin"))).toEqual({ "kick-on-non-admin" })
	end)

	it("offers `all` as the spelled-out wildcard", function()
		expect(policyNamesType().ArgumentOperatorAliases.all).toEqual("*")
	end)

	it("leaves the singular type alone, since both are built from the one table", function()
		-- Nothing in this package takes accessPolicyName any more, the same way nothing takes
		-- accessFactName. Both stay registered for consumers writing their own commands, and neither may be
		-- turned listable by the registration of the plural next to it.
		local cmdr, registered = strictCmdr()
		AccessCommandUtils.registerTypes(cmdr, fakeAccessDataService(), function()
			return { "kick-on-non-admin" }
		end)

		expect(registered.accessPolicyName.Listable).toEqual(nil)
	end)
end)

describe("AccessCommandUtils.describeNameList", function()
	it("names them while a person can still check them", function()
		-- Sorted: Cmdr hands a list argument back in the hash order of its dedupe table, so naming them in
		-- the order they arrive is naming them in an order that means nothing.
		expect(AccessCommandUtils.describeNameList({ "ownsGame", "isStaff" }, "facts")).toEqual("isStaff, ownsGame")
	end)

	it("leaves the caller's list untouched, which is the one the command still has to toggle", function()
		local names = { "ownsGame", "isStaff" }
		AccessCommandUtils.describeNameList(names, "facts")

		expect(names).toEqual({ "ownsGame", "isStaff" })
	end)

	it("counts them once naming them would be a wall", function()
		-- Which is exactly what * produces.
		expect(AccessCommandUtils.describeNameList({ "a", "b", "c", "d", "e" }, "facts")).toEqual("5 facts")
	end)

	it("says something rather than nothing for an empty list", function()
		expect(AccessCommandUtils.describeNameList({}, "facts")).toEqual("no facts")
	end)

	it("names whatever it was given, so a policy list does not read as facts", function()
		expect(AccessCommandUtils.describeNameList({ "a", "b", "c", "d", "e" }, "policies")).toEqual("5 policies")
		expect(AccessCommandUtils.describeNameList({}, "policies")).toEqual("no policies")
	end)
end)

describe("AccessCommandUtils.collectPlayerState", function()
	local function collectingDataService()
		return {
			GetFeatureNames = function()
				return { "chapters" }
			end,
			GetFeature = function(_self, featureName: string)
				return {
					featureName = featureName,
					RequiresSubject = function()
						return false
					end,
				}
			end,
			ObserveFeatureReport = function()
				return Rx.of({
					featureName = "chapters",
					state = AccessStateUtils.allowed({ "isStaff" }),
					facts = { isStaff = staffReport() },
				})
			end,
			ObserveFactReports = function()
				return Rx.of({ isStaff = staffReport() })
			end,
		}
	end

	local function collectingPolicyService()
		return {
			GetPolicyNames = function()
				return { "kick-on-non-admin" }
			end,
			GetPolicy = function()
				return {
					GetFactNames = function()
						return { "isStaff" }
					end,
				}
			end,
			IsPolicyEnabled = function()
				return true
			end,
		}
	end

	it("gathers what a readout needs from whichever realm it runs on", function()
		local collected =
			AccessCommandUtils.collectPlayerState(collectingDataService(), collectingPolicyService(), PLAYER)

		expect(#collected.featureReports).toEqual(1)
		expect(collected.featureReports[1].featureName).toEqual("chapters")
		expect(collected.factReports.isStaff).never.toEqual(nil)
		expect(collected.policies[1].policyName).toEqual("kick-on-non-admin")
	end)

	it("survives a realm with no policies, which is how a bare client comes up", function()
		local collected = AccessCommandUtils.collectPlayerState(collectingDataService(), nil, PLAYER)

		expect(collected.policies).toEqual({})
	end)

	it("renders every section it gathered, so nothing collected goes unprinted", function()
		-- Was written as formatCollected(x) == formatPlayerState(x...), which is the literal body of the
		-- first -- it passed no matter what either function did. Assert the output instead.
		local collected =
			AccessCommandUtils.collectPlayerState(collectingDataService(), collectingPolicyService(), PLAYER)
		local text = AccessCommandUtils.formatCollectedPlayerState(collected)

		expect(string.find(text, "chapters") ~= nil).toEqual(true)
		expect(string.find(text, "isStaff") ~= nil).toEqual(true)
		expect(string.find(text, "kick%-on%-non%-admin") ~= nil).toEqual(true)
		expect(string.find(text, "groupRank") ~= nil).toEqual(true)
	end)

	it("refuses to collect without a player rather than reading a blank state", function()
		expect(function()
			AccessCommandUtils.collectPlayerState(collectingDataService(), nil, nil :: any)
		end).toThrow("No player")
	end)
end)
