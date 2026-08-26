--!strict
local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local CharacterUtils = require("CharacterUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local player: Player = maid:Add(PlayerMock.new())
	player.Parent = Workspace

	local controller = {
		player = player,
		destroy = function()
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

local function getHumanoid(character: Model): Humanoid
	return character:FindFirstChildOfClass("Humanoid") :: Humanoid
end

describe("CharacterUtils.getPlayerHumanoid", function()
	it("returns nil before any character has spawned", function()
		local controller = setup()

		expect(CharacterUtils.getPlayerHumanoid(controller.player)).toBeNil()

		controller.destroy()
	end)

	it("returns the spawned character's humanoid", function()
		local controller = setup()

		local character = PlayerMock.loadMinimalCharacterAsync(controller.player)
		expect(CharacterUtils.getPlayerHumanoid(controller.player)).toBe(getHumanoid(character))

		controller.destroy()
	end)

	it("returns nil after the character despawns", function()
		local controller = setup()

		PlayerMock.loadMinimalCharacterAsync(controller.player)
		PlayerMock.removeCharacter(controller.player)
		expect(CharacterUtils.getPlayerHumanoid(controller.player)).toBeNil()

		controller.destroy()
	end)
end)

describe("CharacterUtils.getAlivePlayerHumanoid", function()
	it("returns the humanoid while it has health", function()
		local controller = setup()

		local character = PlayerMock.loadMinimalCharacterAsync(controller.player)
		expect(CharacterUtils.getAlivePlayerHumanoid(controller.player)).toBe(getHumanoid(character))

		controller.destroy()
	end)

	it("returns nil once the humanoid's health reaches zero", function()
		local controller = setup()

		local character = PlayerMock.loadMinimalCharacterAsync(controller.player)
		getHumanoid(character).Health = 0
		expect(CharacterUtils.getAlivePlayerHumanoid(controller.player)).toBeNil()

		controller.destroy()
	end)

	it("returns nil with no character", function()
		local controller = setup()

		expect(CharacterUtils.getAlivePlayerHumanoid(controller.player)).toBeNil()

		controller.destroy()
	end)
end)

describe("CharacterUtils.getPlayerRootPart", function()
	it("returns the humanoid's root part", function()
		local controller = setup()

		local character = PlayerMock.loadMinimalCharacterAsync(controller.player)
		expect(CharacterUtils.getPlayerRootPart(controller.player)).toBe(character:FindFirstChild("HumanoidRootPart"))

		controller.destroy()
	end)

	it("still returns the root part at zero health", function()
		local controller = setup()

		local character = PlayerMock.loadMinimalCharacterAsync(controller.player)
		getHumanoid(character).Health = 0
		expect(CharacterUtils.getPlayerRootPart(controller.player)).toBe(character:FindFirstChild("HumanoidRootPart"))

		controller.destroy()
	end)

	it("returns nil with no character", function()
		local controller = setup()

		expect(CharacterUtils.getPlayerRootPart(controller.player)).toBeNil()

		controller.destroy()
	end)
end)

describe("CharacterUtils.getAlivePlayerRootPart", function()
	it("returns the root part while the humanoid is alive", function()
		local controller = setup()

		local character = PlayerMock.loadMinimalCharacterAsync(controller.player)
		expect(CharacterUtils.getAlivePlayerRootPart(controller.player)).toBe(
			character:FindFirstChild("HumanoidRootPart")
		)

		controller.destroy()
	end)

	it("returns nil once the humanoid's health reaches zero", function()
		local controller = setup()

		local character = PlayerMock.loadMinimalCharacterAsync(controller.player)
		getHumanoid(character).Health = 0
		expect(CharacterUtils.getAlivePlayerRootPart(controller.player)).toBeNil()

		controller.destroy()
	end)

	it("returns nil with no character", function()
		local controller = setup()

		expect(CharacterUtils.getAlivePlayerRootPart(controller.player)).toBeNil()

		controller.destroy()
	end)
end)

describe("CharacterUtils.unequipTools", function()
	it("removes an equipped tool from the character", function()
		local controller = setup()

		local character = PlayerMock.loadMinimalCharacterAsync(controller.player)

		local tool = Instance.new("Tool")
		tool.RequiresHandle = false
		tool.Parent = character
		expect(tool.Parent).toBe(character)

		CharacterUtils.unequipTools(controller.player)

		-- A mock has no real Backpack for the engine to move the tool into; it unparents instead
		expect(tool.Parent).never.toBe(character)
		tool:Destroy()

		controller.destroy()
	end)

	it("is a no-op with no character", function()
		local controller = setup()

		expect(function()
			CharacterUtils.unequipTools(controller.player)
		end).never.toThrow()

		controller.destroy()
	end)
end)

describe("CharacterUtils.getPlayerFromCharacter", function()
	it("resolves the mock from its character model", function()
		local controller = setup()

		local character = PlayerMock.loadMinimalCharacterAsync(controller.player)
		expect(CharacterUtils.getPlayerFromCharacter(character)).toBe(controller.player)

		controller.destroy()
	end)

	it("resolves the mock from a part of the character", function()
		local controller = setup()

		local character = PlayerMock.loadMinimalCharacterAsync(controller.player)
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
		expect(CharacterUtils.getPlayerFromCharacter(rootPart)).toBe(controller.player)

		controller.destroy()
	end)

	it("resolves the mock from a nested descendant", function()
		local controller = setup()

		local character = PlayerMock.loadMinimalCharacterAsync(controller.player)
		local attachment = Instance.new("Attachment")
		attachment.Parent = character:FindFirstChild("HumanoidRootPart") :: BasePart
		expect(CharacterUtils.getPlayerFromCharacter(attachment)).toBe(controller.player)

		controller.destroy()
	end)

	it("returns nil for an instance outside any character", function()
		local controller = setup()

		local part = Instance.new("Part")
		part.Parent = Workspace
		expect(CharacterUtils.getPlayerFromCharacter(part)).toBeNil()
		part:Destroy()

		controller.destroy()
	end)
end)
