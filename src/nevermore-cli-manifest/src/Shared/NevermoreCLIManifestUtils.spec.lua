--!strict
--[[
	@class NevermoreCLIManifestUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local NevermoreCLIManifestUtils = require("NevermoreCLIManifestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Stamp an instance the same way the nevermore CLI stamps a deployed place, so
-- these specs run anywhere (Studio, plain unit-test VM, cloud) without depending
-- on the CLI's deploy-metadata pass having actually run against the test build.
--
-- We deliberately do NOT assert exact strings. The values a real deploy injects
-- (commit, timestamp, place/universe IDs) change every build, so the point is
-- only that whatever the CLI assigns round-trips through getGameMetadata with a
-- reasonable shape -- IDs are written as strings and must read back as numbers.
local function makeInjectedInstance(): Instance
	local instance = Instance.new("Folder")
	instance:SetAttribute("Deployed", true)
	instance:SetAttribute("Commit", "a1b2c3d")
	instance:SetAttribute("Version", "a1b2c3d4e5f67890a1b2c3d4e5f67890a1b2c3d4")
	instance:SetAttribute("Branch", "main")
	instance:SetAttribute("PackageVersion", "1.0.0")
	instance:SetAttribute("Target", "test")
	instance:SetAttribute("Timestamp", "2026-07-15T00:00:00.000Z")
	instance:SetAttribute("Published", false)
	instance:SetAttribute("PlaceId", "136978232832565")
	instance:SetAttribute("UniverseId", "9716264427")
	-- The whole target's place table, exactly as the CLI stamps it: a JSON
	-- string with numeric IDs (see buildDeployMetadataAttributes). The IDs are
	-- above 2^24 on purpose, to prove the JSON path preserves them.
	instance:SetAttribute(
		"Places",
		'[{"name":"chapter0","placeId":97235312452456,"universeId":9716264427},'
			.. '{"name":"chapter1","placeId":87639818897831,"universeId":9716264427}]'
	)
	return instance
end

describe("NevermoreCLIManifestUtils injection", function()
	it("reports an injected place as deployed", function()
		expect(NevermoreCLIManifestUtils.isDeployed(makeInjectedInstance())).toEqual(true)
	end)

	it("reads reasonable metadata back from the injected attributes", function()
		local metadata = NevermoreCLIManifestUtils.getGameMetadata(makeInjectedInstance())

		expect(metadata.deployed).toEqual(true)

		-- A git commit, not a placeholder: a hex string of plausible length.
		expect(type(metadata.commit)).toEqual("string")
		expect(#(metadata.commit :: string) >= 7).toEqual(true)
		expect(string.match(metadata.commit :: string, "^%x+$")).never.toBeNil()

		-- The full SHA, also hex, and no shorter than the short commit.
		expect(type(metadata.version)).toEqual("string")
		expect(#(metadata.version :: string) >= #(metadata.commit :: string)).toEqual(true)
		expect(string.match(metadata.version :: string, "^%x+$")).never.toBeNil()

		expect(metadata.packageVersion).toEqual("1.0.0")

		expect(metadata.target).toEqual("test")
		expect(metadata.published).toEqual(false)

		expect(type(metadata.timestamp)).toEqual("string")
		expect(#(metadata.timestamp :: string) > 0).toEqual(true)

		-- IDs round-trip through string attributes back to exact numbers.
		expect(type(metadata.placeId)).toEqual("number")
		expect(metadata.placeId > 0).toEqual(true)
		expect(type(metadata.universeId)).toEqual("number")
		expect(metadata.universeId > 0).toEqual(true)
	end)

	it("observes the injected metadata", function()
		local instance = makeInjectedInstance()

		local received
		local sub = NevermoreCLIManifestUtils.observeGameMetadata(instance):Subscribe(function(metadata)
			received = metadata
		end)

		expect(received).never.toBeNil()
		expect(received.deployed).toEqual(true)
		expect(received.commit).toEqual(NevermoreCLIManifestUtils.getGameMetadata(instance).commit)

		sub:Destroy()
	end)
end)

describe("NevermoreCLIManifestUtils without injection", function()
	it("reports an unstamped place as not deployed", function()
		local instance = Instance.new("Folder")
		expect(NevermoreCLIManifestUtils.isDeployed(instance)).toEqual(false)

		local metadata = NevermoreCLIManifestUtils.getGameMetadata(instance)
		expect(metadata.deployed).toEqual(false)
		expect(metadata.commit).toBeNil()
		expect(metadata.placeId).toBeNil()
		expect(metadata.universeId).toBeNil()
	end)
end)

describe("NevermoreCLIManifestUtils place table", function()
	it("reads the whole target's places from the injected table", function()
		local places = NevermoreCLIManifestUtils.getPlaces(makeInjectedInstance())
		expect(#places).toEqual(2)
		expect(places[1].name).toEqual("chapter0")
		expect(places[2].name).toEqual("chapter1")
	end)

	it("preserves large place IDs exactly", function()
		local places = NevermoreCLIManifestUtils.getPlaces(makeInjectedInstance())
		-- Above 2^24: proves the JSON-string path avoids the float32 corruption a
		-- numeric attribute would suffer.
		expect(places[1].placeId).toEqual(97235312452456)
		expect(places[2].placeId).toEqual(87639818897831)
		expect(places[1].universeId).toEqual(9716264427)
	end)

	it("returns an empty list without injection", function()
		expect(#NevermoreCLIManifestUtils.getPlaces(Instance.new("Folder"))).toEqual(0)
	end)

	it("degrades malformed place data to an empty list", function()
		local instance = Instance.new("Folder")
		instance:SetAttribute("Places", "not json{")
		expect(#NevermoreCLIManifestUtils.getPlaces(instance)).toEqual(0)
	end)

	it("observes the injected place table", function()
		local received
		local sub = NevermoreCLIManifestUtils.observePlaces(makeInjectedInstance()):Subscribe(function(places)
			received = places
		end)

		expect(received).never.toBeNil()
		expect(#received).toEqual(2)

		sub:Destroy()
	end)
end)

-- Read the metadata off the *actual* running place (no instance argument). When
-- these specs run through the nevermore CLI's cloud test path the place really
-- was built and stamped by the CLI, so we get to assert the real deploy stamp --
-- the same values a `nevermore deploy` would inject. The standard Jest CI job
-- runs the specs in a plain Roblox VM with no injection, so guard on `deployed`
-- and only assert the un-stamped invariants there rather than forcing a stamp
-- that path never applies.
describe("NevermoreCLIManifestUtils running place", function()
	it("agrees with isDeployed", function()
		local metadata = NevermoreCLIManifestUtils.getGameMetadata()
		expect(type(metadata)).toEqual("table")
		expect(metadata.deployed).toEqual(NevermoreCLIManifestUtils.isDeployed())
	end)

	it("carries a real deploy stamp when deployed by the CLI", function()
		local metadata = NevermoreCLIManifestUtils.getGameMetadata()
		if not metadata.deployed then
			-- Plain Jest VM (or Studio): nothing was injected, so there is no
			-- stamp to assert. The un-stamped shape is covered above.
			expect(metadata.commit).toBeNil()
			return
		end

		-- A real git commit was injected, not a placeholder.
		expect(type(metadata.commit)).toEqual("string")
		expect(#(metadata.commit :: string) >= 7).toEqual(true)
		expect(string.match(metadata.commit :: string, "^%x+$")).never.toBeNil()

		-- Injected by `runSingleTestAsync` for the test build.
		expect(metadata.target).toEqual("test")
		expect(metadata.published).toEqual(false)

		expect(type(metadata.timestamp)).toEqual("string")
		expect(#(metadata.timestamp :: string) > 0).toEqual(true)

		-- The test target's place/universe IDs round-trip back to numbers.
		expect(type(metadata.placeId)).toEqual("number")
		expect(metadata.placeId > 0).toEqual(true)
		expect(type(metadata.universeId)).toEqual("number")
		expect(metadata.universeId > 0).toEqual(true)
	end)
end)
