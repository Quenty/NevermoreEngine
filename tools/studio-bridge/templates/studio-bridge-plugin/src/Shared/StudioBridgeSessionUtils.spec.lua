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
	it("should slug the place name and append the nonce", function()
		expect(StudioBridgeSessionUtils.getInstanceId("My Cool  Place!", "3f9a")).toEqual("my-cool-place-3f9a")
	end)

	it("should drop a place file extension", function()
		expect(StudioBridgeSessionUtils.getInstanceId("test-place.rbxl", "3f9a")).toEqual("test-place-3f9a")
		expect(StudioBridgeSessionUtils.getInstanceId("Map.rbxlx", "3f9a")).toEqual("map-3f9a")
	end)

	it("should keep long names short", function()
		expect(StudioBridgeSessionUtils.getInstanceId("An Extremely Long Place Name For Testing", "3f9a")).toEqual(
			"an-extremely-long-place-3f9a"
		)
	end)

	it("should fall back to place when the name has nothing usable", function()
		expect(StudioBridgeSessionUtils.getInstanceId("!!!", "3f9a")).toEqual("place-3f9a")
		expect(StudioBridgeSessionUtils.getInstanceId(nil, "3f9a")).toEqual("place-3f9a")
	end)
end)

describe("StudioBridgeSessionUtils.getOrCreateNonce()", function()
	it("should keep the first nonce for later calls", function()
		local container = Instance.new("Folder")
		local count = 0
		local function createNonce(): string
			count += 1
			return "nonce" .. tostring(count)
		end

		expect(StudioBridgeSessionUtils.getOrCreateNonce(container, createNonce)).toEqual("nonce1")
		expect(StudioBridgeSessionUtils.getOrCreateNonce(container, createNonce)).toEqual("nonce1")

		container:Destroy()
	end)

	it("should not save the nonce with the place", function()
		local container = Instance.new("Folder")

		StudioBridgeSessionUtils.getOrCreateNonce(container, function()
			return "3f9a"
		end)

		expect((container:FindFirstChild("StudioBridgeNonce") :: Instance).Archivable).toEqual(false)

		container:Destroy()
	end)
end)

describe("StudioBridgeSessionUtils.getLaunchId()", function()
	it("should read the launch id stamped onto the workspace", function()
		local container = Instance.new("Folder")
		container:SetAttribute("StudioBridgeSessionId", "launch-1")

		expect(StudioBridgeSessionUtils.getLaunchId(container)).toEqual("launch-1")

		container:Destroy()
	end)

	it("should be nil for a place the user opened", function()
		local container = Instance.new("Folder")

		expect(StudioBridgeSessionUtils.getLaunchId(container)).toBeNil()

		container:Destroy()
	end)
end)

describe("StudioBridgeSessionUtils.getPlaytestArgs()", function()
	it("should read the port and instance id studio-bridge passed in the test args", function()
		expect(StudioBridgeSessionUtils.getPlaytestArgs({
			studioBridgePlaytestId = "abc",
			studioBridgePort = 38741,
			studioBridgeInstanceId = "test-place-3f9a",
		})).toEqual({ port = 38741, instanceId = "test-place-3f9a", multiplayer = false })
	end)

	it("should report a multiplayer test", function()
		local args = StudioBridgeSessionUtils.getPlaytestArgs({
			studioBridgePort = 38741,
			studioBridgeInstanceId = "test-place-3f9a",
			studioBridgePlayers = 2,
		})

		expect(args and args.multiplayer).toEqual(true)
	end)

	it("should return nil for a playtest studio-bridge did not start", function()
		expect(StudioBridgeSessionUtils.getPlaytestArgs(nil)).toBeNil()
		expect(StudioBridgeSessionUtils.getPlaytestArgs({ custom = true })).toBeNil()
	end)
end)

describe("StudioBridgeSessionUtils.getSessionId()", function()
	it("should append the context to the instance id", function()
		expect(StudioBridgeSessionUtils.getSessionId("test-place-3f9a", "edit")).toEqual("test-place-3f9a-edit")
	end)

	it("should append the player of a multiplayer client", function()
		expect(StudioBridgeSessionUtils.getSessionId("test-place-3f9a", "client", "Player2")).toEqual(
			"test-place-3f9a-client-player2"
		)
	end)
end)

describe("StudioBridgeSessionUtils.getContext()", function()
	it("should be edit when the game is not running", function()
		expect(StudioBridgeSessionUtils.getContext()).toEqual("edit")
	end)
end)

describe("StudioBridgeSessionUtils.createRegisterPayload()", function()
	it("should describe the plugin and the open place", function()
		local payload = StudioBridgeSessionUtils.createRegisterPayload("test-place-3f9a", "edit")

		expect(payload.instanceId).toEqual("test-place-3f9a")
		expect(payload.context).toEqual("edit")
		expect(payload.state).toEqual("Edit")
		expect(payload.placeId).toEqual(game.PlaceId)
		expect(payload.gameId).toEqual(game.GameId)
		expect(type(payload.pluginVersion)).toEqual("string")
		expect(payload.capabilities).toEqual(StudioBridgeSessionUtils.CAPABILITIES)
	end)

	it("should carry the launch id of a Studio that process run launched", function()
		local payload = StudioBridgeSessionUtils.createRegisterPayload("test-place-3f9a", "edit", "launch-1")

		expect(payload.launchId).toEqual("launch-1")
	end)

	it("should carry the player of a multiplayer client", function()
		local payload = StudioBridgeSessionUtils.createRegisterPayload("test-place-3f9a", "client", nil, "Player2")

		expect(payload.playerName).toEqual("Player2")
	end)

	it("should hand out a capabilities list the caller can change", function()
		local payload = StudioBridgeSessionUtils.createRegisterPayload("test-place-3f9a", "edit")

		table.insert(payload.capabilities, "extra")

		expect(table.find(StudioBridgeSessionUtils.CAPABILITIES, "extra")).toBeNil()
	end)
end)
