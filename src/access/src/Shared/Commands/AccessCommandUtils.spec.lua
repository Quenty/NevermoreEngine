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

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

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
		MakeFuzzyFinder = function(list: { string })
			return function()
				return list
			end
		end,
		MakeListableType = function(typeObject: any)
			return typeObject
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

	it("registers every argument type the commands reference", function()
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
				"accessOverrideValue",
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
