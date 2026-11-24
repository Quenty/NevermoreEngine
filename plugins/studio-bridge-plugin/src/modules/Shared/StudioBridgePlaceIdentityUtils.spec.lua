--!strict
--[[
	@class StudioBridgePlaceIdentityUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local StudioBridgePlaceIdentityUtils = require("StudioBridgePlaceIdentityUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function markedWorkspace(attributes: { [string]: any }): Instance
	local folder = Instance.new("Folder")
	for name, value in attributes do
		folder:SetAttribute(name, value)
	end
	return folder
end

-- Stands in for a DataModel: the real one would change the identity of the
-- place running the tests.
local function fakeDataModel(placeId: number, workspace: Instance)
	local calls = {}
	local dataModel = {
		PlaceId = placeId,
		GetService = function(_self, _name: string)
			return workspace
		end,
		SetPlaceId = function(_self, id: number)
			table.insert(calls, { "SetPlaceId", id })
		end,
		SetUniverseId = function(_self, id: number)
			table.insert(calls, { "SetUniverseId", id })
		end,
	}
	return (dataModel :: any) :: DataModel, calls
end

describe("StudioBridgePlaceIdentityUtils.readMarkedIdentity()", function()
	it("should read the ids a build marked the place with", function()
		local workspace = markedWorkspace({ StudioBridgePlaceId = "123", StudioBridgeUniverseId = "456" })
		expect(StudioBridgePlaceIdentityUtils.readMarkedIdentity(workspace)).toEqual({
			placeId = 123,
			universeId = 456,
		})
	end)

	it("should return nil for an unmarked place", function()
		expect(StudioBridgePlaceIdentityUtils.readMarkedIdentity(markedWorkspace({}))).toBeNil()
	end)

	it("should read ids past 2^31 exactly", function()
		local workspace =
			markedWorkspace({ StudioBridgePlaceId = "82695513889773", StudioBridgeUniverseId = "10192566764" })
		expect(StudioBridgePlaceIdentityUtils.readMarkedIdentity(workspace)).toEqual({
			placeId = 82695513889773,
			universeId = 10192566764,
		})
	end)

	it("should ignore a marker that is not a decimal id", function()
		local workspace = markedWorkspace({ StudioBridgePlaceId = "0x7B", StudioBridgeUniverseId = 456 })
		expect(StudioBridgePlaceIdentityUtils.readMarkedIdentity(workspace)).toBeNil()
	end)

	it("should return nil when only one id is marked", function()
		local workspace = markedWorkspace({ StudioBridgePlaceId = "123" })
		expect(StudioBridgePlaceIdentityUtils.readMarkedIdentity(workspace)).toBeNil()
	end)
end)

describe("StudioBridgePlaceIdentityUtils.applyMarkedIdentity()", function()
	it("should give an unpublished place its marked identity", function()
		local workspace = markedWorkspace({ StudioBridgePlaceId = "123", StudioBridgeUniverseId = "456" })
		local dataModel, calls = fakeDataModel(0, workspace)

		local applied = StudioBridgePlaceIdentityUtils.applyMarkedIdentity(dataModel)

		expect(applied).toEqual({ placeId = 123, universeId = 456 })
		expect(calls).toEqual({ { "SetPlaceId", 123 }, { "SetUniverseId", 456 } })
	end)

	it("should leave a place that already has a PlaceId alone", function()
		local workspace = markedWorkspace({ StudioBridgePlaceId = "123", StudioBridgeUniverseId = "456" })
		local dataModel, calls = fakeDataModel(789, workspace)

		expect(StudioBridgePlaceIdentityUtils.applyMarkedIdentity(dataModel)).toBeNil()
		expect(#calls).toEqual(0)
	end)

	it("should do nothing for an unmarked place", function()
		local dataModel, calls = fakeDataModel(0, markedWorkspace({}))

		expect(StudioBridgePlaceIdentityUtils.applyMarkedIdentity(dataModel)).toBeNil()
		expect(#calls).toEqual(0)
	end)
end)
