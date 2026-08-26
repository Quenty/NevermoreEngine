--!strict
local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PlayerUtils = require("PlayerUtils")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local controller = {
		newPlayer = function(overrides: { [string]: any }?): Player
			local player = PlayerMock.new(overrides)
			player.Parent = Players
			maid:GiveTask(player)
			return player
		end,
		destroy = function()
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("PlayerUtils.formatDisplayName", function()
	it("returns the display name when it matches the username", function()
		expect(PlayerUtils.formatDisplayName("oot", "oot")).toBe("oot")
	end)

	it("ignores case when comparing", function()
		expect(PlayerUtils.formatDisplayName("MARTXN", "martxn")).toBe("martxn")
	end)

	it("qualifies the display name with the username when they differ", function()
		expect(PlayerUtils.formatDisplayName("martxn", "oot")).toBe("oot (@martxn)")
	end)
end)

describe("PlayerUtils.formatDisplayNameFromUserInfo", function()
	it("formats without a badge", function()
		expect(PlayerUtils.formatDisplayNameFromUserInfo({
			Username = "martxn",
			DisplayName = "oot",
			HasVerifiedBadge = false,
		})).toBe("oot (@martxn)")
	end)

	it("appends the verified badge", function()
		expect(PlayerUtils.formatDisplayNameFromUserInfo({
			Username = "martxn",
			DisplayName = "oot",
			HasVerifiedBadge = true,
		})).toBe(PlayerUtils.addVerifiedBadgeToName("oot (@martxn)"))
	end)

	it("rejects a malformed userInfo", function()
		expect(function()
			PlayerUtils.formatDisplayNameFromUserInfo({ Username = "martxn" } :: any)
		end).toThrow()
	end)
end)

describe("PlayerUtils.getDefaultNameColor", function()
	it("is stable for the same name", function()
		expect(PlayerUtils.getDefaultNameColor("oot")).toEqual(PlayerUtils.getDefaultNameColor("oot"))
	end)

	it("returns a Color3", function()
		expect(typeof(PlayerUtils.getDefaultNameColor("oot"))).toBe("Color3")
	end)
end)

describe("PlayerUtils.formatName", function()
	it("returns the mock's name when its display name stand-in matches", function()
		local controller = setup()

		local player = controller.newPlayer({ UserId = 8675309 })
		expect(PlayerUtils.formatName(player)).toBe(player.Name)

		controller.destroy()
	end)

	it("qualifies the mock's display name stand-in with its name", function()
		local controller = setup()

		local player = controller.newPlayer({ UserId = 8675309, DisplayName = "oot" })
		expect(PlayerUtils.formatName(player)).toBe(string.format("oot (@%s)", player.Name))

		controller.destroy()
	end)

	it("follows a display name written mid-test", function()
		local controller = setup()

		local player = controller.newPlayer({ UserId = 8675309 })
		PlayerMock.write(player, "DisplayName", "oot")
		expect(PlayerUtils.formatName(player)).toBe(string.format("oot (@%s)", player.Name))

		controller.destroy()
	end)

	it("rejects an instance that is neither a Player nor a mock", function()
		expect(function()
			PlayerUtils.formatName(Instance.new("Folder") :: any)
		end).toThrow()
	end)
end)

describe("PlayerUtils.promiseLoadCharacter", function()
	it("spawns the mock's character and resolves it", function()
		local controller = setup()

		local player = controller.newPlayer({ UserId = 8675309 })
		local outcome, character = PromiseTestUtils.awaitOutcome(PlayerUtils.promiseLoadCharacter(player), 30)

		expect(outcome).toBe("resolved")
		expect(character).toBe(PlayerMock.read(player, "Character"))
		expect(character.Parent).toBe(workspace)

		controller.destroy()
	end)

	it("rejects an instance that is neither a Player nor a mock", function()
		expect(function()
			PlayerUtils.promiseLoadCharacter(Instance.new("Folder") :: any)
		end).toThrow()
	end)
end)

describe("PlayerUtils.promiseLoadCharacterWithHumanoidDescription", function()
	it("spawns a rig built from the description and resolves it", function()
		local controller = setup()

		local player = controller.newPlayer({ UserId = 8675309 })
		local description = Instance.new("HumanoidDescription")

		local outcome, character = PromiseTestUtils.awaitOutcome(
			PlayerUtils.promiseLoadCharacterWithHumanoidDescription(player, description),
			30
		)

		expect(outcome).toBe("resolved")
		expect(character).toBe(PlayerMock.read(player, "Character"))
		expect(character:FindFirstChildOfClass("Humanoid")).never.toBeNil()

		description:Destroy()
		controller.destroy()
	end)

	it("rejects a bad humanoidDescription", function()
		local controller = setup()

		local player = controller.newPlayer({ UserId = 8675309 })
		expect(function()
			PlayerUtils.promiseLoadCharacterWithHumanoidDescription(player, Instance.new("Folder") :: any)
		end).toThrow()

		controller.destroy()
	end)
end)
