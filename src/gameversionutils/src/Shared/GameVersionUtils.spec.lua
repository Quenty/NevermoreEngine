--!strict
--[[
	Covers the version string format itself. [GameVersionUtils.formatVersionString]
	takes its metadata and build as arguments, so every case below -- including
	ones that cannot happen in a test place, like a production deploy -- is
	exercised without depending on how this place was built.

	@class GameVersionUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local GameVersionUtils = require("GameVersionUtils")
local Jest = require("Jest")
local NevermoreCLIManifestUtils = require("NevermoreCLIManifestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function deployedMetadata(overrides: { [string]: any }?): NevermoreCLIManifestUtils.GameMetadata
	local metadata: any = {
		deployed = true,
		commit = "a4a79e8",
		version = "a4a79e8b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f",
		branch = "main",
		packageVersion = "1.0.0",
		target = "integration",
		timestamp = "2026-07-15T00:00:00.000Z",
		published = true,
	}

	if overrides then
		for key, value in overrides do
			metadata[key] = value
		end
	end

	return metadata
end

describe("GameVersionUtils.formatVersionString", function()
	it("reports package version, environment, commit and place version", function()
		expect(GameVersionUtils.formatVersionString(deployedMetadata(), "312")).toEqual(
			"1.0.0 · integration · a4a79e8 · v312"
		)
	end)

	it("does not prefix the commit with a v", function()
		local text = GameVersionUtils.formatVersionString(deployedMetadata(), "312")

		expect(string.find(text, "va4a79e8", 1, true)).toBeNil()
	end)

	it("includes the branch when a build did not come from a default branch", function()
		local metadata = deployedMetadata({ branch = "users/quenty/hintbar", target = "test" })

		expect(GameVersionUtils.formatVersionString(metadata, "8")).toEqual(
			"1.0.0 · test · users/quenty/hintbar · a4a79e8 · v8"
		)
	end)

	it("omits the branch for master as well as main", function()
		local metadata = deployedMetadata({ branch = "master" })

		expect(GameVersionUtils.formatVersionString(metadata, "312")).toEqual("1.0.0 · integration · a4a79e8 · v312")
	end)

	it("keeps the environment for every target name", function()
		local metadata = deployedMetadata({ target = "production-demo" })

		expect(GameVersionUtils.formatVersionString(metadata, "312")).toEqual(
			"1.0.0 · production-demo · a4a79e8 · v312"
		)
	end)

	it("drops fields an older CLI did not stamp", function()
		local metadata: any = { deployed = true, target = "production" }

		expect(GameVersionUtils.formatVersionString(metadata, "312")).toEqual("production · v312")
	end)

	it("says unknown when a deploy did not record its target", function()
		local metadata = deployedMetadata({ target = nil })

		expect(GameVersionUtils.formatVersionString(metadata, "312")).toEqual("1.0.0 · unknown · a4a79e8 · v312")
	end)

	it("reports a studio session with no metadata as studio", function()
		expect(GameVersionUtils.formatVersionString({ deployed = false }, "studio")).toEqual("studio")
	end)

	it("reports a live place with no metadata as undeployed", function()
		expect(GameVersionUtils.formatVersionString({ deployed = false }, "312")).toEqual("undeployed · v312")
	end)

	it("keeps deploy metadata when a deployed place is opened in studio", function()
		expect(GameVersionUtils.formatVersionString(deployedMetadata(), "studio")).toEqual(
			"1.0.0 · integration · a4a79e8 · studio"
		)
	end)
end)

describe("GameVersionUtils.formatVersionString config", function()
	it("takes a separator without having to restate the rest of the format", function()
		expect(GameVersionUtils.formatVersionString(deployedMetadata(), "312", { separator = " | " })).toEqual(
			"1.0.0 | integration | a4a79e8 | v312"
		)
	end)

	it("takes a place version prefix", function()
		expect(GameVersionUtils.formatVersionString(deployedMetadata(), "312", { placeVersionPrefix = "place " })).toEqual(
			"1.0.0 · integration · a4a79e8 · place 312"
		)
	end)

	it("takes the set of branches not worth reporting", function()
		local config = { defaultBranches = { integration = true } }
		local metadata = deployedMetadata({ branch = "integration" })

		expect(GameVersionUtils.formatVersionString(metadata, "312", config)).toEqual(
			"1.0.0 · integration · a4a79e8 · v312"
		)
		expect(GameVersionUtils.formatVersionString(deployedMetadata(), "312", config)).toEqual(
			"1.0.0 · integration · main · a4a79e8 · v312"
		)
	end)

	it("takes the labels used when metadata is missing", function()
		local config = { undeployedLabel = "hand-published", unknownTargetLabel = "?" }

		expect(GameVersionUtils.formatVersionString({ deployed = false }, "312", config)).toEqual(
			"hand-published · v312"
		)
		expect(GameVersionUtils.formatVersionString(deployedMetadata({ target = nil }), "312", config)).toEqual(
			"1.0.0 · ? · a4a79e8 · v312"
		)
	end)
end)

describe("GameVersionUtils.getEnvironmentName", function()
	it("returns a target name or nothing at all, never a placeholder", function()
		local environment = GameVersionUtils.getEnvironmentName()

		if environment ~= nil then
			expect(type(environment)).toEqual("string")
			expect(#environment > 0).toEqual(true)
		end
	end)

	it("agrees with the manifest about whether this place was deployed", function()
		local deployed = NevermoreCLIManifestUtils.getGameMetadata().deployed

		if not deployed then
			expect(GameVersionUtils.getEnvironmentName()).toBeNil()
		end
	end)
end)

describe("GameVersionUtils.getVersionString", function()
	it("describes the running place without erroring", function()
		local text = GameVersionUtils.getVersionString()

		expect(type(text)).toEqual("string")
		expect(#text > 0).toEqual(true)
	end)
end)
