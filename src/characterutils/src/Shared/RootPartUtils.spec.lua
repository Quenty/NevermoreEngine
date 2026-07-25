--!strict
local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local RootPartUtils = require("RootPartUtils")

local afterEach = Jest.Globals.afterEach
local beforeEach = Jest.Globals.beforeEach
local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local maid: Maid.Maid = nil :: any
local player: Player = nil :: any

beforeEach(function()
	maid = Maid.new()
	player = PlayerMock.new()
	player.Parent = Workspace -- the leave path needs an ancestry to change
end)

afterEach(function()
	maid:DoCleaning() -- settles any promise left pending, so no poll outlives the test
	player:Destroy()
end)

local function getRootPart(character: Model): BasePart
	return character:FindFirstChild("HumanoidRootPart") :: BasePart
end

describe("RootPartUtils.promisePlayerHumanoidRootPart", function()
	it("resolves already with the root part of a spawned character", function()
		local character = PlayerMock.loadMinimalCharacterAsync(player)

		local promise = maid:Add(RootPartUtils.promisePlayerHumanoidRootPart(player))
		expect(promise:IsFulfilled()).toBe(true)

		local ok, rootPart = promise:Yield()
		expect(ok).toBe(true)
		expect(rootPart).toBe(getRootPart(character))
	end)

	it("stays pending until a character spawns", function()
		local promise = maid:Add(RootPartUtils.promisePlayerHumanoidRootPart(player))
		expect(promise:IsPending()).toBe(true)

		local character = PlayerMock.loadMinimalCharacterAsync(player)

		local ok, rootPart = promise:Yield()
		expect(ok).toBe(true)
		expect(rootPart).toBe(getRootPart(character))
	end)

	it("resolves with the root part of the character present when it spawns, not a despawned one", function()
		local firstCharacter = PlayerMock.loadMinimalCharacterAsync(player)
		local firstRootPart = getRootPart(firstCharacter)
		PlayerMock.removeCharacter(player)

		local promise = maid:Add(RootPartUtils.promisePlayerHumanoidRootPart(player))
		expect(promise:IsPending()).toBe(true)

		local secondCharacter = PlayerMock.loadMinimalCharacterAsync(player)

		local ok, rootPart = promise:Yield()
		expect(ok).toBe(true)
		expect(rootPart).toBe(getRootPart(secondCharacter))
		expect(rootPart).never.toBe(firstRootPart)
	end)

	it("resolves for a dead humanoid, which still has a root part", function()
		local character = PlayerMock.loadMinimalCharacterAsync(player)
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Health = 0

		local promise = maid:Add(RootPartUtils.promisePlayerHumanoidRootPart(player))

		local ok, rootPart = promise:Yield()
		expect(ok).toBe(true)
		expect(rootPart).toBe(getRootPart(character))
	end)

	it("resolves once a humanoid is added to a character that spawned without one", function()
		local character = Instance.new("Model")

		local rootPart = Instance.new("Part")
		rootPart.Name = "HumanoidRootPart"
		rootPart.Anchored = true
		rootPart.Parent = character
		character.PrimaryPart = rootPart

		PlayerMock.loadCharacterAsync(player, character)

		local promise = maid:Add(RootPartUtils.promisePlayerHumanoidRootPart(player))
		expect(promise:IsPending()).toBe(true)

		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character

		local ok, resolved = promise:Yield()
		expect(ok).toBe(true)
		expect(resolved).toBe(rootPart)
	end)

	it("rejects when the player leaves the game", function()
		local promise = maid:Add(RootPartUtils.promisePlayerHumanoidRootPart(player))
		expect(promise:IsPending()).toBe(true)

		PlayerMock.kick(player)

		local ok, err = promise:Yield()
		expect(ok).toBe(false)
		expect(err).toBe("Player removed from game")
	end)

	it("rejects a value that is neither a Player nor a PlayerMock", function()
		local folder = Instance.new("Folder")

		expect(function()
			RootPartUtils.promisePlayerHumanoidRootPart(folder :: any)
		end).toThrow()

		folder:Destroy()
	end)
end)

describe("RootPartUtils.getPlayerRootPart", function()
	it("returns the root part of a spawned character", function()
		local character = PlayerMock.loadMinimalCharacterAsync(player)

		expect(RootPartUtils.getPlayerRootPart(player)).toBe(getRootPart(character))
	end)

	it("returns nil when the player has no character", function()
		expect(RootPartUtils.getPlayerRootPart(player)).toBe(nil)
	end)

	it("returns nil once the character is removed", function()
		PlayerMock.loadMinimalCharacterAsync(player)
		PlayerMock.removeCharacter(player)

		expect(RootPartUtils.getPlayerRootPart(player)).toBe(nil)
	end)

	it("returns nil for a character without a humanoid", function()
		local character = Instance.new("Model")

		local rootPart = Instance.new("Part")
		rootPart.Name = "HumanoidRootPart"
		rootPart.Anchored = true
		rootPart.Parent = character
		character.PrimaryPart = rootPart

		PlayerMock.loadCharacterAsync(player, character)

		expect(RootPartUtils.getPlayerRootPart(player)).toBe(nil)
	end)

	it("returns the root part for a dead humanoid", function()
		local character = PlayerMock.loadMinimalCharacterAsync(player)
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Health = 0

		expect(RootPartUtils.getPlayerRootPart(player)).toBe(getRootPart(character))
	end)

	it("rejects a value that is neither a Player nor a PlayerMock", function()
		local folder = Instance.new("Folder")

		expect(function()
			RootPartUtils.getPlayerRootPart(folder :: any)
		end).toThrow()

		folder:Destroy()
	end)
end)
