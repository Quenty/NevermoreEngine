--!strict
--[[
	@class PlayerMockCharacterUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PlayerMockCharacterUtils = require("PlayerMockCharacterUtils")
local PlayerMockChildrenUtils = require("PlayerMockChildrenUtils")
local PlayerMockPropertyUtils = require("PlayerMockPropertyUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PlayerMockCharacterUtils.loadMinimalCharacterAsync", function()
	it("builds an anchored HumanoidRootPart as the PrimaryPart, alongside a Humanoid", function()
		local player = PlayerMock.new()
		local character = PlayerMockCharacterUtils.loadMinimalCharacterAsync(player)

		expect(character.PrimaryPart).never.toBeNil()
		expect((character.PrimaryPart :: BasePart).Name).toBe("HumanoidRootPart")
		expect((character.PrimaryPart :: BasePart).Anchored).toBe(true)
		expect(character:FindFirstChildOfClass("Humanoid")).never.toBeNil()

		player:Destroy()
	end)

	it("names the character after the mock and parents it into Workspace", function()
		local player = PlayerMock.new()
		local character = PlayerMockCharacterUtils.loadMinimalCharacterAsync(player)

		expect(character.Name).toBe((player :: Instance).Name)
		expect(character.Parent).toBe(Workspace)

		player:Destroy()
	end)

	it("assigns the Character property and fires CharacterAdded before CharacterAppearanceLoaded", function()
		local player = PlayerMock.new()
		local order = {}

		local addedConnection = PlayerMock.getSignal(player, "CharacterAdded"):Connect(function()
			table.insert(order, "added")
		end)
		local loadedConnection = PlayerMock.getSignal(player, "CharacterAppearanceLoaded"):Connect(function()
			table.insert(order, "loaded")
		end)

		local character = PlayerMockCharacterUtils.loadMinimalCharacterAsync(player)

		expect(PlayerMockPropertyUtils.read(player, "Character")).toBe(character)
		expect(order).toEqual({ "added", "loaded" })
		expect(PlayerMockPropertyUtils.read(player, "HasAppearanceLoaded")).toBe(true)

		addedConnection:Disconnect()
		loadedConnection:Disconnect()
		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")

		expect(function()
			PlayerMockCharacterUtils.loadMinimalCharacterAsync(folder :: any)
		end).toThrow()

		folder:Destroy()
	end)
end)

describe("PlayerMockCharacterUtils.loadCharacterAsync", function()
	it("takes the character model it is given", function()
		local player = PlayerMock.new()
		local model = Instance.new("Model")

		expect(PlayerMockCharacterUtils.loadCharacterAsync(player, model)).toBe(model)

		player:Destroy()
	end)

	it("gives the spawn a Backpack and a StarterGear", function()
		local player = PlayerMock.new()
		PlayerMockCharacterUtils.loadCharacterAsync(player, Instance.new("Model"))

		expect(PlayerMockChildrenUtils.getBackpack(player)).never.toBeNil()
		expect(PlayerMockChildrenUtils.getStarterGear(player)).never.toBeNil()

		player:Destroy()
	end)

	it("replaces the Backpack on respawn but keeps the StarterGear, like the engine", function()
		local player = PlayerMock.new()
		PlayerMockCharacterUtils.loadCharacterAsync(player, Instance.new("Model"))

		local firstBackpack = PlayerMockChildrenUtils.getBackpack(player)
		local firstStarterGear = PlayerMockChildrenUtils.getStarterGear(player)

		PlayerMockCharacterUtils.loadCharacterAsync(player, Instance.new("Model"))

		expect(PlayerMockChildrenUtils.getBackpack(player)).never.toBe(firstBackpack)
		expect(PlayerMockChildrenUtils.getStarterGear(player)).toBe(firstStarterGear)

		player:Destroy()
	end)

	it("throws on something that is not a Model", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockCharacterUtils.loadCharacterAsync(player, Instance.new("Folder") :: any)
		end).toThrow()

		player:Destroy()
	end)
end)

describe("PlayerMockCharacterUtils.removeCharacter", function()
	it("nils the Character property and destroys the model", function()
		local player = PlayerMock.new()
		local character = PlayerMockCharacterUtils.loadMinimalCharacterAsync(player)

		PlayerMockCharacterUtils.removeCharacter(player)

		expect(PlayerMockPropertyUtils.read(player, "Character")).toBeNil()
		expect(character.Parent).toBeNil()

		player:Destroy()
	end)

	it("is a no-op when no character is loaded", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockCharacterUtils.removeCharacter(player)
		end).never.toThrow()

		player:Destroy()
	end)
end)

describe("PlayerMockCharacterUtils.getMockFromCharacter", function()
	it("finds the mock whose Character stand-in is that model", function()
		local player = PlayerMock.new()
		player.Parent = Workspace
		local character = PlayerMockCharacterUtils.loadMinimalCharacterAsync(player)

		expect(PlayerMockCharacterUtils.getMockFromCharacter(character)).toBe(player)

		player:Destroy()
	end)

	it("is nil for a descendant, leaving callers their own ancestor walk", function()
		local player = PlayerMock.new()
		player.Parent = Workspace
		local character = PlayerMockCharacterUtils.loadMinimalCharacterAsync(player)

		expect(PlayerMockCharacterUtils.getMockFromCharacter((character.PrimaryPart :: any) :: Instance)).toBeNil()

		player:Destroy()
	end)

	it("is nil for a model no mock is wearing", function()
		local model = Instance.new("Model")

		expect(PlayerMockCharacterUtils.getMockFromCharacter(model)).toBeNil()

		model:Destroy()
	end)

	it("throws on something that is not an Instance", function()
		expect(function()
			PlayerMockCharacterUtils.getMockFromCharacter(5 :: any)
		end).toThrow()
	end)
end)
