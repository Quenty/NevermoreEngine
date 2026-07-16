--!nonstrict
--[[
	@class NevermoreCLIManifestUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local NevermoreCLIManifestUtils = require("NevermoreCLIManifestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Arbitrary values the test controls from end to end -- NOT real deploy data.
-- The assertions read back out of this same table, so nothing here needs to
-- track what an actual deployment injects; the point is only that whatever the
-- CLI assigns as attributes round-trips through getGameMetadata with the right
-- shape and types (IDs are assigned as strings and read back as numbers).
local FIXTURE = {
	Deployed = true,
	Commit = "a1b2c3d",
	Version = "a1b2c3d4e5f67890",
	Branch = "main",
	Target = "integration",
	Timestamp = "2026-07-15T00:00:00.000Z",
	Published = true,
	PlaceId = "123456789",
	UniverseId = "987654321",
}

local function makeInjectedInstance(): Instance
	local instance = Instance.new("Folder")
	for name, value in FIXTURE do
		instance:SetAttribute(name, value)
	end
	return instance
end

describe("NevermoreCLIManifestUtils.getGameMetadata", function()
	it("reads back every attribute the CLI assigns", function()
		local metadata = NevermoreCLIManifestUtils.getGameMetadata(makeInjectedInstance())
		expect(metadata.deployed).toEqual(true)
		expect(metadata.commit).toEqual(FIXTURE.Commit)
		expect(metadata.version).toEqual(FIXTURE.Version)
		expect(metadata.branch).toEqual(FIXTURE.Branch)
		expect(metadata.target).toEqual(FIXTURE.Target)
		expect(metadata.timestamp).toEqual(FIXTURE.Timestamp)
		expect(metadata.published).toEqual(true)
	end)

	it("converts stringified place/universe IDs back to exact numbers", function()
		local metadata = NevermoreCLIManifestUtils.getGameMetadata(makeInjectedInstance())
		expect(metadata.placeId).toEqual(tonumber(FIXTURE.PlaceId))
		expect(metadata.universeId).toEqual(tonumber(FIXTURE.UniverseId))
	end)

	it("reports not deployed when nothing was assigned", function()
		local metadata = NevermoreCLIManifestUtils.getGameMetadata(Instance.new("Folder"))
		expect(metadata.deployed).toEqual(false)
		expect(metadata.commit).toBeNil()
		expect(metadata.placeId).toBeNil()
	end)
end)

-- No hardcoded values here: the running place's metadata changes every deploy,
-- so assert shape and self-consistency against the actual place instead.
describe("NevermoreCLIManifestUtils.getGameMetadata (running place)", function()
	it("returns a well-formed table that agrees with isDeployed", function()
		local metadata = NevermoreCLIManifestUtils.getGameMetadata()
		expect(type(metadata)).toEqual("table")
		expect(type(metadata.deployed)).toEqual("boolean")
		expect(metadata.deployed).toEqual(NevermoreCLIManifestUtils.isDeployed())
	end)

	it("is internally consistent when actually deployed", function()
		local metadata = NevermoreCLIManifestUtils.getGameMetadata()
		if not metadata.deployed then
			-- Undeployed (Studio or a plain test build): nothing was injected.
			expect(metadata.commit).toBeNil()
			return
		end

		expect(type(metadata.commit)).toEqual("string")
		expect(#metadata.commit > 0).toEqual(true)
		expect(type(metadata.timestamp)).toEqual("string")
		-- The injected place ID must match the place we are running in.
		expect(metadata.placeId).toEqual(game.PlaceId)
	end)
end)

describe("NevermoreCLIManifestUtils.observeGameMetadata", function()
	it("fires immediately with the current snapshot", function()
		local received
		local sub = NevermoreCLIManifestUtils.observeGameMetadata(makeInjectedInstance()):Subscribe(function(metadata)
			received = metadata
		end)

		expect(received).never.toBeNil()
		expect(received.target).toEqual(FIXTURE.Target)

		sub:Destroy()
	end)
end)
