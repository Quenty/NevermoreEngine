--!strict
--[[
	@class PlayerMockPropertyUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PlayerMockConstants = require("PlayerMockConstants")
local PlayerMockPropertyUtils = require("PlayerMockPropertyUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PlayerMockPropertyUtils.seedProperties", function()
	it("leaves a fresh mock answering the pre-authored defaults", function()
		local player = PlayerMock.new()

		expect(PlayerMockPropertyUtils.read(player, "UserId")).toBe(0)
		expect(PlayerMockPropertyUtils.read(player, "AccountAge")).toBe(0)
		expect(PlayerMockPropertyUtils.read(player, "HasVerifiedBadge")).toBe(false)
		expect(PlayerMockPropertyUtils.read(player, "MembershipType")).toBe(Enum.MembershipType.None)

		player:Destroy()
	end)

	it("takes the overrides it is given", function()
		local player = PlayerMock.new({ UserId = 12345, AccountAge = 30 })

		expect(PlayerMockPropertyUtils.read(player, "UserId")).toBe(12345)
		expect(PlayerMockPropertyUtils.read(player, "AccountAge")).toBe(30)

		player:Destroy()
	end)

	it("defaults DisplayName to the mock's own name", function()
		local player = PlayerMock.new()

		expect(PlayerMockPropertyUtils.read(player, "DisplayName")).toBe((player :: Instance).Name)

		player:Destroy()
	end)

	it("leaves the Instance-valued properties nil, like a real Player before spawn", function()
		local player = PlayerMock.new()

		expect(PlayerMockPropertyUtils.read(player, "Character")).toBeNil()
		expect(PlayerMockPropertyUtils.read(player, "RespawnLocation")).toBeNil()

		player:Destroy()
	end)
end)

describe("PlayerMockPropertyUtils.write", function()
	it("round-trips a value read reflects", function()
		local player = PlayerMock.new()
		PlayerMockPropertyUtils.write(player, "AccountAge", 99)

		expect(PlayerMockPropertyUtils.read(player, "AccountAge")).toBe(99)

		player:Destroy()
	end)

	it("round-trips an EnumItem through its backing attribute", function()
		local player = PlayerMock.new()
		PlayerMockPropertyUtils.write(player, "MembershipType", Enum.MembershipType.Premium)

		expect((player :: Instance):GetAttribute("MembershipType")).toBe("Premium")
		expect(PlayerMockPropertyUtils.read(player, "MembershipType")).toBe(Enum.MembershipType.Premium)

		player:Destroy()
	end)

	it("backs an Instance-valued property with an ObjectValue child rather than an attribute", function()
		local player = PlayerMock.new()
		local spawnLocation = Instance.new("SpawnLocation")

		PlayerMockPropertyUtils.write(player, "RespawnLocation", spawnLocation)

		expect((player :: Instance):GetAttribute("RespawnLocation")).toBeNil()
		expect(
			(player :: Instance):FindFirstChild(PlayerMockConstants.PROPERTY_OBJECT_NAME_PREFIX .. "RespawnLocation")
		).never.toBeNil()
		expect(PlayerMockPropertyUtils.read(player, "RespawnLocation")).toBe(spawnLocation)

		player:Destroy()
		spawnLocation:Destroy()
	end)

	it("throws on a non-Instance value for an Instance-valued property", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockPropertyUtils.write(player, "RespawnLocation", 5 :: any)
		end).toThrow()

		player:Destroy()
	end)
end)

describe("PlayerMockPropertyUtils service properties", function()
	it("is nil before anything is written, without creating a backing", function()
		local player = PlayerMock.new()

		expect(PlayerMockPropertyUtils.read(player, "GuiService.SelectedObject")).toBeNil()
		expect(
			(player :: Instance):FindFirstChild(
				PlayerMockConstants.PROPERTY_OBJECT_NAME_PREFIX .. "GuiService_SelectedObject"
			)
		).toBeNil()

		player:Destroy()
	end)

	it("round-trips through a backing named for the flattened path", function()
		local player = PlayerMock.new()
		local frame = Instance.new("Frame")

		PlayerMockPropertyUtils.write(player, "GuiService.SelectedObject", frame)

		expect(PlayerMockPropertyUtils.read(player, "GuiService.SelectedObject")).toBe(frame)
		expect(
			(player :: Instance):FindFirstChild(
				PlayerMockConstants.PROPERTY_OBJECT_NAME_PREFIX .. "GuiService_SelectedObject"
			)
		).never.toBeNil()

		player:Destroy()
		frame:Destroy()
	end)

	it("clears back to nil", function()
		local player = PlayerMock.new()
		local frame = Instance.new("Frame")

		PlayerMockPropertyUtils.write(player, "GuiService.SelectedObject", frame)
		PlayerMockPropertyUtils.write(player, "GuiService.SelectedObject", nil)

		expect(PlayerMockPropertyUtils.read(player, "GuiService.SelectedObject")).toBeNil()

		player:Destroy()
		frame:Destroy()
	end)

	it("keeps each mock's copy of the client-global member apart", function()
		local first = PlayerMock.new()
		local second = PlayerMock.new()
		local frame = Instance.new("Frame")

		PlayerMockPropertyUtils.write(first, "GuiService.SelectedObject", frame)

		expect(PlayerMockPropertyUtils.read(second, "GuiService.SelectedObject")).toBeNil()

		first:Destroy()
		second:Destroy()
		frame:Destroy()
	end)

	it("fires the changed signal over the backing a later write lands on", function()
		local player = PlayerMock.new()
		local frame = Instance.new("Frame")
		local fired = 0

		local signal = PlayerMockPropertyUtils.getPropertyChangedSignal(player, "GuiService.SelectedObject")
		local connection = signal:Connect(function()
			fired += 1
		end)
		PlayerMockPropertyUtils.write(player, "GuiService.SelectedObject", frame)

		expect(fired).toBe(1)

		connection:Disconnect()
		player:Destroy()
		frame:Destroy()
	end)

	it("accepts the path table form", function()
		local player = PlayerMock.new()
		local frame = Instance.new("Frame")

		PlayerMockPropertyUtils.write(player, { "GuiService", "SelectedObject" }, frame)

		expect(PlayerMockPropertyUtils.read(player, "GuiService.SelectedObject")).toBe(frame)

		player:Destroy()
		frame:Destroy()
	end)

	it("rejects a class the engine does not reflect", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockPropertyUtils.read(player, "NotAService.SelectedObject")
		end).toThrow()

		player:Destroy()
	end)

	it("rejects a member the real service does not have", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockPropertyUtils.read(player, "GuiService.SelectedGuiObject")
		end).toThrow()

		player:Destroy()
	end)

	it("rejects a path deeper than a service member", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockPropertyUtils.read(player, "GuiService.SelectedObject.Name")
		end).toThrow()

		player:Destroy()
	end)
end)

describe("PlayerMockPropertyUtils property names", function()
	it("rejects a name no Player property has", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockPropertyUtils.read(player, "UserID")
		end).toThrow()
		expect(function()
			PlayerMockPropertyUtils.write(player, "UserID", 1)
		end).toThrow()
		expect(function()
			PlayerMockPropertyUtils.getPropertyChangedSignal(player, "UserID")
		end).toThrow()

		player:Destroy()
	end)

	it("accepts a real Player property it pre-authors no default for", function()
		local player = PlayerMock.new()

		expect(PlayerMockPropertyUtils._isProperty("Team")).toBe(true)
		expect(PlayerMockPropertyUtils.read(player, "Team")).toBeNil()

		player:Destroy()
	end)

	it("accepts a modelled member reflection reports as a method rather than a property", function()
		expect(PlayerMockPropertyUtils._isProperty("HasAppearanceLoaded")).toBe(true)
	end)

	it("explains itself when it rejects a name", function()
		local isValid, message = PlayerMockPropertyUtils._isProperty("UserID")

		expect(isValid).toBe(false)
		expect(type(message)).toBe("string")
	end)
end)

describe("PlayerMockPropertyUtils.getPropertyChangedSignal", function()
	it("fires for an attribute-backed property", function()
		local player = PlayerMock.new()
		local fired = 0

		local connection = PlayerMockPropertyUtils.getPropertyChangedSignal(player, "AccountAge"):Connect(function()
			fired += 1
		end)
		PlayerMockPropertyUtils.write(player, "AccountAge", 7)

		expect(fired).toBe(1)

		connection:Disconnect()
		player:Destroy()
	end)

	it("fires for an ObjectValue-backed property", function()
		local player = PlayerMock.new()
		local character = Instance.new("Model")
		local fired = 0

		local connection = PlayerMockPropertyUtils.getPropertyChangedSignal(player, "Character"):Connect(function()
			fired += 1
		end)
		PlayerMockPropertyUtils.write(player, "Character", character)

		expect(fired).toBe(1)

		connection:Disconnect()
		player:Destroy()
	end)
end)
