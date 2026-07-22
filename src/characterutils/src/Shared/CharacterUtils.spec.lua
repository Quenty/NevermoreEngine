--!strict
local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local CharacterUtils = require("CharacterUtils")
local Jest = require("Jest")
local PlayerMock = require("PlayerMock")

local afterEach = Jest.Globals.afterEach
local beforeEach = Jest.Globals.beforeEach
local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local player: Player = nil :: any

beforeEach(function()
	player = PlayerMock.new()
	player.Parent = Workspace -- getPlayerFromCharacter's mock resolution is DataModel-scoped
end)

afterEach(function()
	player:Destroy()
end)

local function getHumanoid(character: Model): Humanoid
	return character:FindFirstChildOfClass("Humanoid") :: Humanoid
end

describe("CharacterUtils.getPlayerHumanoid", function()
	it("returns nil before any character has spawned", function()
		expect(CharacterUtils.getPlayerHumanoid(player)).toBeNil()
	end)

	it("returns the spawned character's humanoid", function()
		local character = PlayerMock.loadMinimalCharacterAsync(player)
		expect(CharacterUtils.getPlayerHumanoid(player)).toBe(getHumanoid(character))
	end)

	it("returns nil after the character despawns", function()
		PlayerMock.loadMinimalCharacterAsync(player)
		PlayerMock.removeCharacter(player)
		expect(CharacterUtils.getPlayerHumanoid(player)).toBeNil()
	end)
end)

describe("CharacterUtils.getAlivePlayerHumanoid", function()
	it("returns the humanoid while it has health", function()
		local character = PlayerMock.loadMinimalCharacterAsync(player)
		expect(CharacterUtils.getAlivePlayerHumanoid(player)).toBe(getHumanoid(character))
	end)

	it("returns nil once the humanoid's health reaches zero", function()
		local character = PlayerMock.loadMinimalCharacterAsync(player)
		getHumanoid(character).Health = 0
		expect(CharacterUtils.getAlivePlayerHumanoid(player)).toBeNil()
	end)

	it("returns nil with no character", function()
		expect(CharacterUtils.getAlivePlayerHumanoid(player)).toBeNil()
	end)
end)

describe("CharacterUtils.getPlayerRootPart", function()
	it("returns the humanoid's root part", function()
		local character = PlayerMock.loadMinimalCharacterAsync(player)
		expect(CharacterUtils.getPlayerRootPart(player)).toBe(character:FindFirstChild("HumanoidRootPart"))
	end)

	it("still returns the root part at zero health", function()
		local character = PlayerMock.loadMinimalCharacterAsync(player)
		getHumanoid(character).Health = 0
		expect(CharacterUtils.getPlayerRootPart(player)).toBe(character:FindFirstChild("HumanoidRootPart"))
	end)

	it("returns nil with no character", function()
		expect(CharacterUtils.getPlayerRootPart(player)).toBeNil()
	end)
end)

describe("CharacterUtils.getAlivePlayerRootPart", function()
	it("returns the root part while the humanoid is alive", function()
		local character = PlayerMock.loadMinimalCharacterAsync(player)
		expect(CharacterUtils.getAlivePlayerRootPart(player)).toBe(character:FindFirstChild("HumanoidRootPart"))
	end)

	it("returns nil once the humanoid's health reaches zero", function()
		local character = PlayerMock.loadMinimalCharacterAsync(player)
		getHumanoid(character).Health = 0
		expect(CharacterUtils.getAlivePlayerRootPart(player)).toBeNil()
	end)

	it("returns nil with no character", function()
		expect(CharacterUtils.getAlivePlayerRootPart(player)).toBeNil()
	end)
end)

describe("CharacterUtils.unequipTools", function()
	it("removes an equipped tool from the character", function()
		local character = PlayerMock.loadMinimalCharacterAsync(player)

		local tool = Instance.new("Tool")
		tool.RequiresHandle = false
		tool.Parent = character
		expect(tool.Parent).toBe(character)

		CharacterUtils.unequipTools(player)

		-- A mock has no real Backpack for the engine to move the tool into; it unparents instead
		expect(tool.Parent).never.toBe(character)
		tool:Destroy()
	end)

	it("is a no-op with no character", function()
		expect(function()
			CharacterUtils.unequipTools(player)
		end).never.toThrow()
	end)
end)

describe("CharacterUtils.getPlayerFromCharacter", function()
	it("resolves the mock from its character model", function()
		local character = PlayerMock.loadMinimalCharacterAsync(player)
		expect(CharacterUtils.getPlayerFromCharacter(character)).toBe(player)
	end)

	it("resolves the mock from a part of the character", function()
		local character = PlayerMock.loadMinimalCharacterAsync(player)
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
		expect(CharacterUtils.getPlayerFromCharacter(rootPart)).toBe(player)
	end)

	it("resolves the mock from a nested descendant", function()
		local character = PlayerMock.loadMinimalCharacterAsync(player)
		local attachment = Instance.new("Attachment")
		attachment.Parent = character:FindFirstChild("HumanoidRootPart") :: BasePart
		expect(CharacterUtils.getPlayerFromCharacter(attachment)).toBe(player)
	end)

	it("returns nil for an instance outside any character", function()
		local part = Instance.new("Part")
		part.Parent = Workspace
		expect(CharacterUtils.getPlayerFromCharacter(part)).toBeNil()
		part:Destroy()
	end)
end)
