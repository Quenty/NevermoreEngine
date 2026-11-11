--!strict
local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local RootPartUtils = require("RootPartUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local player: Player = PlayerMock.new()
	player.Parent = Workspace

	local controller = {
		maid = maid,
		player = player,
		Destroy = function(_self)
			-- Destroying the player first fires the leave path, rejecting a pending
			-- promisePlayerHumanoidRootPart with nobody to consume it.
			maid:DoCleaning()
			player:Destroy()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

local function getRootPart(character: Model): BasePart
	return character:FindFirstChild("HumanoidRootPart") :: BasePart
end

describe("RootPartUtils.promisePlayerHumanoidRootPart", function()
	it("resolves already with the root part of a spawned character", function()
		local controller = setup()

		local character = PlayerMock.loadMinimalCharacterAsync(controller.player)

		local promise = controller.maid:Add(RootPartUtils.promisePlayerHumanoidRootPart(controller.player))
		expect(promise:IsFulfilled()).toBe(true)

		local ok, rootPart = promise:Yield()
		expect(ok).toBe(true)
		expect(rootPart).toBe(getRootPart(character))

		controller:Destroy()
	end)

	it("stays pending until a character spawns", function()
		local controller = setup()

		local promise = controller.maid:Add(RootPartUtils.promisePlayerHumanoidRootPart(controller.player))
		expect(promise:IsPending()).toBe(true)

		local character = PlayerMock.loadMinimalCharacterAsync(controller.player)

		local ok, rootPart = promise:Yield()
		expect(ok).toBe(true)
		expect(rootPart).toBe(getRootPart(character))

		controller:Destroy()
	end)

	it("resolves with the root part of the character present when it spawns, not a despawned one", function()
		local controller = setup()

		local firstCharacter = PlayerMock.loadMinimalCharacterAsync(controller.player)
		local firstRootPart = getRootPart(firstCharacter)
		PlayerMock.removeCharacter(controller.player)

		local promise = controller.maid:Add(RootPartUtils.promisePlayerHumanoidRootPart(controller.player))
		expect(promise:IsPending()).toBe(true)

		local secondCharacter = PlayerMock.loadMinimalCharacterAsync(controller.player)

		local ok, rootPart = promise:Yield()
		expect(ok).toBe(true)
		expect(rootPart).toBe(getRootPart(secondCharacter))
		expect(rootPart).never.toBe(firstRootPart)

		controller:Destroy()
	end)

	it("resolves for a dead humanoid, which still has a root part", function()
		local controller = setup()

		local character = PlayerMock.loadMinimalCharacterAsync(controller.player)
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Health = 0

		local promise = controller.maid:Add(RootPartUtils.promisePlayerHumanoidRootPart(controller.player))

		local ok, rootPart = promise:Yield()
		expect(ok).toBe(true)
		expect(rootPart).toBe(getRootPart(character))

		controller:Destroy()
	end)

	it("resolves once a humanoid is added to a character that spawned without one", function()
		local controller = setup()

		local character = Instance.new("Model")

		local rootPart = Instance.new("Part")
		rootPart.Name = "HumanoidRootPart"
		rootPart.Anchored = true
		rootPart.Parent = character
		character.PrimaryPart = rootPart

		PlayerMock.loadCharacterAsync(controller.player, character)

		local promise = controller.maid:Add(RootPartUtils.promisePlayerHumanoidRootPart(controller.player))
		expect(promise:IsPending()).toBe(true)

		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character

		local ok, resolved = promise:Yield()
		expect(ok).toBe(true)
		expect(resolved).toBe(rootPart)

		controller:Destroy()
	end)

	it("rejects when the player leaves the game", function()
		local controller = setup()

		local promise = controller.maid:Add(RootPartUtils.promisePlayerHumanoidRootPart(controller.player))
		expect(promise:IsPending()).toBe(true)

		PlayerMock.kick(controller.player)

		local ok, err = promise:Yield()
		expect(ok).toBe(false)
		expect(err).toBe("Player removed from game")

		controller:Destroy()
	end)

	it("rejects a value that is neither a Player nor a PlayerMock", function()
		local controller = setup()

		local folder = Instance.new("Folder")

		expect(function()
			RootPartUtils.promisePlayerHumanoidRootPart(folder :: any)
		end).toThrow()

		folder:Destroy()

		controller:Destroy()
	end)
end)

describe("RootPartUtils.getPlayerRootPart", function()
	it("returns the root part of a spawned character", function()
		local controller = setup()

		local character = PlayerMock.loadMinimalCharacterAsync(controller.player)

		expect(RootPartUtils.getPlayerRootPart(controller.player)).toBe(getRootPart(character))

		controller:Destroy()
	end)

	it("returns nil when the player has no character", function()
		local controller = setup()

		expect(RootPartUtils.getPlayerRootPart(controller.player)).toBe(nil)

		controller:Destroy()
	end)

	it("returns nil once the character is removed", function()
		local controller = setup()

		PlayerMock.loadMinimalCharacterAsync(controller.player)
		PlayerMock.removeCharacter(controller.player)

		expect(RootPartUtils.getPlayerRootPart(controller.player)).toBe(nil)

		controller:Destroy()
	end)

	it("returns nil for a character without a humanoid", function()
		local controller = setup()

		local character = Instance.new("Model")

		local rootPart = Instance.new("Part")
		rootPart.Name = "HumanoidRootPart"
		rootPart.Anchored = true
		rootPart.Parent = character
		character.PrimaryPart = rootPart

		PlayerMock.loadCharacterAsync(controller.player, character)

		expect(RootPartUtils.getPlayerRootPart(controller.player)).toBe(nil)

		controller:Destroy()
	end)

	it("returns the root part for a dead humanoid", function()
		local controller = setup()

		local character = PlayerMock.loadMinimalCharacterAsync(controller.player)
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Health = 0

		expect(RootPartUtils.getPlayerRootPart(controller.player)).toBe(getRootPart(character))

		controller:Destroy()
	end)

	it("rejects a value that is neither a Player nor a PlayerMock", function()
		local controller = setup()

		local folder = Instance.new("Folder")

		expect(function()
			RootPartUtils.getPlayerRootPart(folder :: any)
		end).toThrow()

		folder:Destroy()

		controller:Destroy()
	end)
end)
