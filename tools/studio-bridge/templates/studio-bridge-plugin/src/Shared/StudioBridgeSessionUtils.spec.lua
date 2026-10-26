--!strict
--[[
	@class StudioBridgeSessionUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local StudioBridgeSessionUtils = require("StudioBridgeSessionUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("StudioBridgeSessionUtils.getInstanceId()", function()
	it("should use the game and place ids for a published place", function()
		expect(StudioBridgeSessionUtils.getInstanceId(123, 456, "My Place", "abcd1234")).toEqual("123-456")
	end)

	it("should use the ids when only the place id is set", function()
		expect(StudioBridgeSessionUtils.getInstanceId(0, 456, "My Place", "abcd1234")).toEqual("0-456")
	end)

	it("should use the sanitized place name and nonce for an unpublished place", function()
		expect(StudioBridgeSessionUtils.getInstanceId(0, 0, "My Cool  Place!", "abcd1234")).toEqual(
			"local-my-cool-place-abcd1234"
		)
	end)

	it("should fall back to untitled when the name has nothing usable", function()
		expect(StudioBridgeSessionUtils.getInstanceId(0, 0, "!!!", "abcd1234")).toEqual("local-untitled-abcd1234")
		expect(StudioBridgeSessionUtils.getInstanceId(0, 0, nil, "abcd1234")).toEqual("local-untitled-abcd1234")
	end)
end)

describe("StudioBridgeSessionUtils.getSessionId()", function()
	it("should append the context to the instance id", function()
		expect(StudioBridgeSessionUtils.getSessionId("123-456", "edit")).toEqual("123-456-edit")
	end)
end)

describe("StudioBridgeSessionUtils.getContext()", function()
	it("should be edit when the game is not running", function()
		expect(StudioBridgeSessionUtils.getContext()).toEqual("edit")
	end)
end)

describe("StudioBridgeSessionUtils.createRegisterPayload()", function()
	it("should describe the plugin and the open place", function()
		local payload = StudioBridgeSessionUtils.createRegisterPayload("123-456", "edit")

		expect(payload.instanceId).toEqual("123-456")
		expect(payload.context).toEqual("edit")
		expect(payload.state).toEqual("Edit")
		expect(payload.placeId).toEqual(game.PlaceId)
		expect(payload.gameId).toEqual(game.GameId)
		expect(type(payload.pluginVersion)).toEqual("string")
		expect(payload.capabilities).toEqual(StudioBridgeSessionUtils.CAPABILITIES)
	end)

	it("should hand out a capabilities list the caller can change", function()
		local payload = StudioBridgeSessionUtils.createRegisterPayload("123-456", "edit")

		table.insert(payload.capabilities, "extra")

		expect(table.find(StudioBridgeSessionUtils.CAPABILITIES, "extra")).toBeNil()
	end)
end)
