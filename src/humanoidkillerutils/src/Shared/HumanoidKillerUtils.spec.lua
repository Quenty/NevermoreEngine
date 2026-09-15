--!strict
--[[
	@class HumanoidKillerUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local HumanoidKillerUtils = require("HumanoidKillerUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local TAG_NAME = "creator"
local TAG_LIFETIME = 1

type Controller = {
	newHumanoid: () -> Humanoid,
	newPlayer: () -> Player,
	newPlayerHumanoid: (player: Player) -> Humanoid,
	newPart: () -> Part,
	getTags: (humanoid: Humanoid) -> { ObjectValue },
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local function newHumanoid(): Humanoid
		local character = Instance.new("Model")

		local rootPart = Instance.new("Part")
		rootPart.Name = "HumanoidRootPart"
		rootPart.Anchored = true
		rootPart.Parent = character
		character.PrimaryPart = rootPart

		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character

		character.Parent = Workspace
		maid:GiveTask(character)

		return humanoid
	end

	local function newPlayer(): Player
		local player: Player = maid:Add(PlayerMock.new())
		player.Parent = Workspace
		return player
	end

	local controller: Controller = {
		newHumanoid = newHumanoid,
		newPlayer = newPlayer,

		newPlayerHumanoid = function(player)
			local character = PlayerMock.loadMinimalCharacterAsync(player)
			return character:FindFirstChildWhichIsA("Humanoid") :: Humanoid
		end,

		newPart = function()
			local part = Instance.new("Part")
			part.Anchored = true
			part.Parent = Workspace
			maid:GiveTask(part)
			return part
		end,

		getTags = function(humanoid)
			local found = {}
			for _, item in humanoid:GetChildren() do
				if item:IsA("ObjectValue") and item.Name == TAG_NAME then
					table.insert(found, item)
				end
			end
			return found
		end,

		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("HumanoidKillerUtils.tagKiller", function()
	it("tags the humanoid with the attacking player", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local player = controller.newPlayer()

		HumanoidKillerUtils.tagKiller(humanoid, player)

		local tags = controller.getTags(humanoid)
		expect(#tags).toBe(1)
		expect(tags[1].Value).toBe(player)

		controller:Destroy()
	end)

	it("tags the humanoid with an attacking humanoid", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local attacker = controller.newHumanoid()

		HumanoidKillerUtils.tagKiller(humanoid, attacker)

		local tags = controller.getTags(humanoid)
		expect(#tags).toBe(1)
		expect(tags[1].Value).toBe(attacker)

		controller:Destroy()
	end)

	it("returns the tag it parented into the humanoid", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local player = controller.newPlayer()

		local creator = HumanoidKillerUtils.tagKiller(humanoid, player)

		expect(creator.Name).toBe(TAG_NAME)
		expect(creator.Parent).toBe(humanoid)

		controller:Destroy()
	end)

	it("replaces a previous tag instead of stacking", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local first = controller.newPlayer()
		local second = controller.newPlayer()

		HumanoidKillerUtils.tagKiller(humanoid, first)
		HumanoidKillerUtils.tagKiller(humanoid, second)

		local tags = controller.getTags(humanoid)
		expect(#tags).toBe(1)
		expect(tags[1].Value).toBe(second)

		controller:Destroy()
	end)

	it("expires the tag after the tag lifetime", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local player = controller.newPlayer()

		HumanoidKillerUtils.tagKiller(humanoid, player)
		task.wait(TAG_LIFETIME + 0.5)

		expect(#controller.getTags(humanoid)).toBe(0)

		controller:Destroy()
	end)

	it("rejects a humanoid that is not an instance", function()
		local controller = setup()
		local player = controller.newPlayer()

		expect(function()
			HumanoidKillerUtils.tagKiller(nil :: any, player)
		end).toThrow("Bad humanoid")

		controller:Destroy()
	end)

	it("rejects an attacker that is not an instance", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		expect(function()
			HumanoidKillerUtils.tagKiller(humanoid, nil :: any)
		end).toThrow("Bad attacker")

		controller:Destroy()
	end)
end)

describe("HumanoidKillerUtils.untagKiller", function()
	it("removes the tag", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local player = controller.newPlayer()

		HumanoidKillerUtils.tagKiller(humanoid, player)
		HumanoidKillerUtils.untagKiller(humanoid)

		expect(#controller.getTags(humanoid)).toBe(0)

		controller:Destroy()
	end)

	it("removes every tag on the humanoid", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local player = controller.newPlayer()

		for _ = 1, 3 do
			local creator = Instance.new("ObjectValue")
			creator.Name = TAG_NAME
			creator.Value = player
			creator.Parent = humanoid
		end

		HumanoidKillerUtils.untagKiller(humanoid)

		expect(#controller.getTags(humanoid)).toBe(0)

		controller:Destroy()
	end)

	it("leaves other children of the humanoid alone", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local player = controller.newPlayer()

		local sameName = Instance.new("StringValue")
		sameName.Name = TAG_NAME
		sameName.Parent = humanoid

		local otherName = Instance.new("ObjectValue")
		otherName.Name = "notCreator"
		otherName.Value = player
		otherName.Parent = humanoid

		HumanoidKillerUtils.tagKiller(humanoid, player)
		HumanoidKillerUtils.untagKiller(humanoid)

		expect(sameName.Parent).toBe(humanoid)
		expect(otherName.Parent).toBe(humanoid)

		controller:Destroy()
	end)

	it("does nothing on an untagged humanoid", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		expect(function()
			HumanoidKillerUtils.untagKiller(humanoid)
		end).never.toThrow()

		controller:Destroy()
	end)
end)

describe("HumanoidKillerUtils.getKillerHumanoidOfHumanoid", function()
	it("returns nil when the humanoid is untagged", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		expect(HumanoidKillerUtils.getKillerHumanoidOfHumanoid(humanoid)).toBeNil()

		controller:Destroy()
	end)

	it("returns the attacking humanoid", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local attacker = controller.newHumanoid()

		HumanoidKillerUtils.tagKiller(humanoid, attacker)

		expect(HumanoidKillerUtils.getKillerHumanoidOfHumanoid(humanoid)).toBe(attacker)

		controller:Destroy()
	end)

	it("returns the humanoid of the attacking player character", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local player = controller.newPlayer()
		local attacker = controller.newPlayerHumanoid(player)

		HumanoidKillerUtils.tagKiller(humanoid, player)

		expect(HumanoidKillerUtils.getKillerHumanoidOfHumanoid(humanoid)).toBe(attacker)

		controller:Destroy()
	end)

	it("returns nil when the attacking player has no character", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local player = controller.newPlayer()

		HumanoidKillerUtils.tagKiller(humanoid, player)

		expect(HumanoidKillerUtils.getKillerHumanoidOfHumanoid(humanoid)).toBeNil()

		controller:Destroy()
	end)

	it("returns nil once the attacking player character despawns", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local player = controller.newPlayer()
		controller.newPlayerHumanoid(player)

		HumanoidKillerUtils.tagKiller(humanoid, player)
		PlayerMock.removeCharacter(player)

		expect(HumanoidKillerUtils.getKillerHumanoidOfHumanoid(humanoid)).toBeNil()

		controller:Destroy()
	end)

	it("returns nil when the tag has been cleared", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local player = controller.newPlayer()

		local creator = HumanoidKillerUtils.tagKiller(humanoid, player)
		creator.Value = nil

		expect(HumanoidKillerUtils.getKillerHumanoidOfHumanoid(humanoid)).toBeNil()

		controller:Destroy()
	end)

	it("returns nil when the tag is not an object value", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local creator = Instance.new("StringValue")
		creator.Name = TAG_NAME
		creator.Parent = humanoid

		expect(HumanoidKillerUtils.getKillerHumanoidOfHumanoid(humanoid)).toBeNil()

		controller:Destroy()
	end)

	it("returns nil when the killer is neither a player nor a humanoid", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		HumanoidKillerUtils.tagKiller(humanoid, controller.newPart() :: any)

		expect(HumanoidKillerUtils.getKillerHumanoidOfHumanoid(humanoid)).toBeNil()

		controller:Destroy()
	end)

	it("rejects a humanoid that is not an instance", function()
		local controller = setup()

		expect(function()
			HumanoidKillerUtils.getKillerHumanoidOfHumanoid(nil :: any)
		end).toThrow("Bad humanoid")

		controller:Destroy()
	end)
end)

describe("HumanoidKillerUtils.getPlayerKillerOfHumanoid", function()
	it("returns nil when the humanoid is untagged", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		expect(HumanoidKillerUtils.getPlayerKillerOfHumanoid(humanoid)).toBeNil()

		controller:Destroy()
	end)

	it("returns the attacking player", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local player = controller.newPlayer()
		controller.newPlayerHumanoid(player)

		HumanoidKillerUtils.tagKiller(humanoid, player)

		expect(HumanoidKillerUtils.getPlayerKillerOfHumanoid(humanoid)).toBe(player)

		controller:Destroy()
	end)

	it("returns the attacking player that has no character", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local player = controller.newPlayer()

		HumanoidKillerUtils.tagKiller(humanoid, player)

		expect(HumanoidKillerUtils.getPlayerKillerOfHumanoid(humanoid)).toBe(player)

		controller:Destroy()
	end)

	it("returns nil when the killer is a humanoid", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local attacker = controller.newHumanoid()

		HumanoidKillerUtils.tagKiller(humanoid, attacker)

		expect(HumanoidKillerUtils.getPlayerKillerOfHumanoid(humanoid)).toBeNil()

		controller:Destroy()
	end)

	it("returns nil once the attacking player has left the game", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local player = controller.newPlayer()

		HumanoidKillerUtils.tagKiller(humanoid, player)
		player.Parent = nil

		expect(HumanoidKillerUtils.getPlayerKillerOfHumanoid(humanoid)).toBeNil()

		controller:Destroy()
	end)

	it("returns nil when the tag has been cleared", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		local player = controller.newPlayer()

		local creator = HumanoidKillerUtils.tagKiller(humanoid, player)
		creator.Value = nil

		expect(HumanoidKillerUtils.getPlayerKillerOfHumanoid(humanoid)).toBeNil()

		controller:Destroy()
	end)

	it("returns nil when the tag is not an object value", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local creator = Instance.new("StringValue")
		creator.Name = TAG_NAME
		creator.Parent = humanoid

		expect(HumanoidKillerUtils.getPlayerKillerOfHumanoid(humanoid)).toBeNil()

		controller:Destroy()
	end)

	it("rejects a humanoid that is not an instance", function()
		local controller = setup()

		expect(function()
			HumanoidKillerUtils.getPlayerKillerOfHumanoid(nil :: any)
		end).toThrow("Bad humanoid")

		controller:Destroy()
	end)
end)
