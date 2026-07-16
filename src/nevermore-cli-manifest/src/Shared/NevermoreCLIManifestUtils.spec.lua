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

-- These specs run inside a place the nevermore CLI built and stamped, so we are
-- asserting the *real* metadata the CLI injected onto this package's module --
-- not a synthetic fixture. If injection did not run, `deployed` is false and
-- these fail, which is the point: they prove the CLI actually stamped the build.
describe("NevermoreCLIManifestUtils injection", function()
	it("marks the running place as deployed", function()
		expect(NevermoreCLIManifestUtils.isDeployed()).toEqual(true)
	end)

	it("exposes the metadata the CLI injected", function()
		local metadata = NevermoreCLIManifestUtils.getGameMetadata()

		expect(metadata.deployed).toEqual(true)

		-- A real git commit was injected, not a placeholder.
		expect(type(metadata.commit)).toEqual("string")
		expect(#metadata.commit >= 7).toEqual(true)
		expect(string.match(metadata.commit, "^%x+$")).never.toBeNil()

		expect(metadata.target).toEqual("test")
		expect(metadata.published).toEqual(false)

		expect(type(metadata.timestamp)).toEqual("string")
		expect(#metadata.timestamp > 0).toEqual(true)

		-- IDs round-trip through string attributes back to exact numbers.
		expect(type(metadata.placeId)).toEqual("number")
		expect(metadata.placeId > 0).toEqual(true)
		expect(type(metadata.universeId)).toEqual("number")
		expect(metadata.universeId > 0).toEqual(true)
	end)

	it("observes the injected metadata", function()
		local received
		local sub = NevermoreCLIManifestUtils.observeGameMetadata():Subscribe(function(metadata)
			received = metadata
		end)

		expect(received).never.toBeNil()
		expect(received.deployed).toEqual(true)
		expect(received.commit).toEqual(NevermoreCLIManifestUtils.getGameMetadata().commit)

		sub:Destroy()
	end)
end)
