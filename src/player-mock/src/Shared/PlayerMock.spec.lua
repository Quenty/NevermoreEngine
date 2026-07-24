--!strict
--[[
	@class PlayerMock.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local afterEach = Jest.Globals.afterEach

describe("PlayerMock.new", function()
	it("is a real Instance so it satisfies typeof == Instance guards", function()
		local player = PlayerMock.new()
		expect(typeof(player)).toBe("Instance")
		player:Destroy()
	end)

	it("is recognized by isMock", function()
		local player = PlayerMock.new()
		expect(PlayerMock.isMock(player)).toBe(true)
		player:Destroy()
	end)

	it("seeds the UserId from the overrides", function()
		local player = PlayerMock.new({ UserId = 12345 })
		expect(PlayerMock.read(player, "UserId")).toBe(12345)
		player:Destroy()
	end)

	it("defaults UserId to 0 when not provided", function()
		local player = PlayerMock.new()
		expect(PlayerMock.read(player, "UserId")).toBe(0)
		player:Destroy()
	end)

	it("accepts extra attributes hung off it, like a real player", function()
		local player = PlayerMock.new({ UserId = 7 })
		player:SetAttribute("ActiveSlotId", "slot-xyz")
		expect(player:GetAttribute("ActiveSlotId")).toBe("slot-xyz")
		player:Destroy()
	end)

	it("asserts on a non-table overrides", function()
		expect(function()
			PlayerMock.new("nope" :: any)
		end).toThrow()
	end)

	it("asserts on a non-number UserId override", function()
		expect(function()
			PlayerMock.new({ UserId = "nope" :: any })
		end).toThrow()
	end)
end)

describe("PlayerMock.isMock", function()
	it("returns false for a plain Folder", function()
		local folder = Instance.new("Folder")
		expect(PlayerMock.isMock(folder)).toBe(false)
		folder:Destroy()
	end)

	it("returns false for a Folder carrying only a PlayerMock attribute", function()
		local folder = Instance.new("Folder")
		folder:SetAttribute("PlayerMock", true)
		expect(PlayerMock.isMock(folder)).toBe(false)
		folder:Destroy()
	end)

	it("returns false for a tagged non-Folder", function()
		local part = Instance.new("Part")
		CollectionService:AddTag(part, PlayerMock.TAG)
		expect(PlayerMock.isMock(part)).toBe(false)
		part:Destroy()
	end)

	it("returns false for non-instance values", function()
		expect(PlayerMock.isMock(nil)).toBe(false)
		expect(PlayerMock.isMock(5)).toBe(false)
		expect(PlayerMock.isMock({ UserId = 1 })).toBe(false)
		expect(PlayerMock.isMock("player")).toBe(false)
	end)
end)

describe("PlayerMock.findFirstAncestorMock", function()
	it("resolves the mock from a direct child", function()
		local player = PlayerMock.new({ UserId = 12345 })
		local child = Instance.new("Configuration")
		child.Parent = player

		expect(PlayerMock.findFirstAncestorMock(child)).toBe(player)
		player:Destroy()
	end)

	it("resolves the mock through intermediate non-mock ancestors", function()
		local player = PlayerMock.new({ UserId = 12345 })
		local folder = Instance.new("Folder")
		folder.Parent = player
		local child = Instance.new("Configuration")
		child.Parent = folder

		expect(PlayerMock.findFirstAncestorMock(child)).toBe(player)
		player:Destroy()
	end)

	it("returns nil when no mock ancestor exists", function()
		local folder = Instance.new("Folder")
		local child = Instance.new("Configuration")
		child.Parent = folder

		expect(PlayerMock.findFirstAncestorMock(child)).toBeNil()
		folder:Destroy()
	end)

	it("never returns the instance itself, like the engine ancestor walk", function()
		local player = PlayerMock.new({ UserId = 12345 })

		expect(PlayerMock.findFirstAncestorMock(player)).toBeNil()
		player:Destroy()
	end)

	it("throws on a non-Instance value", function()
		expect(function()
			PlayerMock.findFirstAncestorMock(nil :: any)
		end).toThrow()
	end)
end)

describe("PlayerMock.getMockByUserId", function()
	it("resolves a parented mock by its seeded UserId", function()
		local player = PlayerMock.new({ UserId = 90011002 })
		player.Parent = Workspace

		expect(PlayerMock.getMockByUserId(90011002)).toBe(player)
		player:Destroy()
	end)

	it("returns nil when no mock matches", function()
		local player = PlayerMock.new({ UserId = 90011003 })
		player.Parent = Workspace

		expect(PlayerMock.getMockByUserId(90011004)).toBeNil()
		player:Destroy()
	end)

	it("returns nil for an unparented mock, like the engine's DataModel-scoped resolve", function()
		local player = PlayerMock.new({ UserId = 90011005 })

		expect(PlayerMock.getMockByUserId(90011005)).toBeNil()
		player:Destroy()
	end)

	it("returns nil after the mock is destroyed", function()
		local player = PlayerMock.new({ UserId = 90011006 })
		player.Parent = Workspace
		player:Destroy()

		expect(PlayerMock.getMockByUserId(90011006)).toBeNil()
	end)

	it("throws on a non-number userId", function()
		expect(function()
			PlayerMock.getMockByUserId("nope" :: any)
		end).toThrow()
	end)
end)

describe("PlayerMock.getMockFromCharacter", function()
	it("resolves a parented mock from its exact character model", function()
		local player = PlayerMock.new()
		player.Parent = Workspace
		local character = PlayerMock.loadMinimalCharacterAsync(player)

		expect(PlayerMock.getMockFromCharacter(character)).toBe(player)
		player:Destroy()
	end)

	it("returns nil for a descendant part, like the engine's exact-model match", function()
		local player = PlayerMock.new()
		player.Parent = Workspace
		local character = PlayerMock.loadMinimalCharacterAsync(player)
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: Instance

		expect(PlayerMock.getMockFromCharacter(rootPart)).toBeNil()
		player:Destroy()
	end)

	it("returns nil for an unparented mock, like the engine's DataModel-scoped resolve", function()
		local player = PlayerMock.new()
		local character = PlayerMock.loadMinimalCharacterAsync(player)

		expect(PlayerMock.getMockFromCharacter(character)).toBeNil()
		player:Destroy()
	end)

	it("returns nil for a model that is no mock's character", function()
		local model = Instance.new("Model")
		expect(PlayerMock.getMockFromCharacter(model)).toBeNil()
		model:Destroy()
	end)

	it("throws on a non-Instance value", function()
		expect(function()
			PlayerMock.getMockFromCharacter(nil :: any)
		end).toThrow()
	end)
end)

describe("PlayerMock.read", function()
	it("returns the pre-authored typed default for an unseeded property", function()
		local player = PlayerMock.new()
		expect(PlayerMock.read(player, "AccountAge")).toBe(0)
		expect(PlayerMock.read(player, "HasVerifiedBadge")).toBe(false)
		player:Destroy()
	end)

	it("returns the overridden value when seeded", function()
		local player = PlayerMock.new({ AccountAge = 30 })
		expect(PlayerMock.read(player, "AccountAge")).toBe(30)
		player:Destroy()
	end)

	it("round-trips an EnumItem-typed property (MembershipType) through its name", function()
		local player = PlayerMock.new()
		expect(PlayerMock.read(player, "MembershipType")).toBe(Enum.MembershipType.None)

		local premium = PlayerMock.new({ MembershipType = Enum.MembershipType.Premium })
		expect(PlayerMock.read(premium, "MembershipType")).toBe(Enum.MembershipType.Premium)

		player:Destroy()
		premium:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.read(folder :: any, "AccountAge")
		end).toThrow()
		folder:Destroy()
	end)
end)

describe("PlayerMock.write", function()
	it("mocks a new value that read reflects", function()
		local player = PlayerMock.new({ AccountAge = 1 })
		PlayerMock.write(player, "AccountAge", 99)
		expect(PlayerMock.read(player, "AccountAge")).toBe(99)
		player:Destroy()
	end)

	it("fires GetAttributeChangedSignal for the property", function()
		local player = PlayerMock.new()
		local fired = false
		local conn = player:GetAttributeChangedSignal("AccountAge"):Connect(function()
			fired = true
		end)

		PlayerMock.write(player, "AccountAge", 5)
		expect(fired).toBe(true)

		conn:Disconnect()
		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.write(folder :: any, "AccountAge", 1)
		end).toThrow()
		folder:Destroy()
	end)
end)

describe("PlayerMock Character property", function()
	it("defaults to nil, like a real Player before spawn", function()
		local player = PlayerMock.new()
		expect(PlayerMock.read(player, "Character")).toBeNil()
		player:Destroy()
	end)

	it("round-trips a character Model through its ObjectValue backing", function()
		local player = PlayerMock.new()
		local character = Instance.new("Model")

		PlayerMock.write(player, "Character", character)
		expect(PlayerMock.read(player, "Character")).toBe(character)

		PlayerMock.write(player, "Character", nil)
		expect(PlayerMock.read(player, "Character")).toBeNil()

		character:Destroy()
		player:Destroy()
	end)

	it("errors on a non-Instance value", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.write(player, "Character", "not a model" :: any)
		end).toThrow()
		player:Destroy()
	end)

	it("Character = nil despawns: CharacterRemoving, property nils while alive, then the model is destroyed", function()
		local player = PlayerMock.new()
		local character = PlayerMock.loadCharacterAsync(player, Instance.new("Model"))

		local log = {}
		local removingConn = PlayerMock.getSignal(player, "CharacterRemoving"):Connect(function(removing)
			table.insert(
				log,
				string.format(
					"removing current=%s parented=%s",
					tostring(PlayerMock.read(player, "Character") == removing),
					tostring(removing.Parent ~= nil)
				)
			)
		end)
		local propertyConn = PlayerMock.getPropertyChangedSignal(player, "Character"):Connect(function()
			local current = PlayerMock.read(player, "Character")
			table.insert(
				log,
				string.format("property=%s destroyed=%s", tostring(current), tostring(character.Parent == nil))
			)
		end)

		PlayerMock.write(player, "Character", nil)

		expect(log).toEqual({
			"removing current=true parented=true",
			"property=nil destroyed=false",
		})
		expect(character.Parent).toBeNil()

		removingConn:Disconnect()
		propertyConn:Disconnect()
		player:Destroy()
	end)

	it("assigning a different model does not remove the old one (the morph pattern destroys it manually)", function()
		local player = PlayerMock.new()
		local first = PlayerMock.loadCharacterAsync(player, Instance.new("Model"))

		local removingFired = false
		local conn = PlayerMock.getSignal(player, "CharacterRemoving"):Connect(function()
			removingFired = true
		end)

		local morph = Instance.new("Model")
		PlayerMock.write(player, "Character", morph)

		expect(removingFired).toBe(false)
		expect(first.Parent).toBe(workspace) -- old character left in place for the caller to handle
		expect(PlayerMock.read(player, "Character")).toBe(morph)

		conn:Disconnect()
		first:Destroy()
		morph:Destroy()
		player:Destroy()
	end)

	it("destroying the mock removes its character, like a player leaving or being kicked", function()
		local player = PlayerMock.new()
		local character = PlayerMock.loadCharacterAsync(player)

		local removingFired = false
		local conn = PlayerMock.getSignal(player, "CharacterRemoving"):Connect(function(removing)
			removingFired = removing == character
		end)

		player:Destroy()

		expect(removingFired).toBe(true)
		expect(character.Parent).toBeNil()

		conn:Disconnect()
	end)
end)

describe("PlayerMock.getPropertyChangedSignal", function()
	it("fires for an attribute-backed property", function()
		local player = PlayerMock.new()
		local fired = false
		local conn = PlayerMock.getPropertyChangedSignal(player, "AccountAge"):Connect(function()
			fired = true
		end)

		PlayerMock.write(player, "AccountAge", 5)
		expect(fired).toBe(true)

		conn:Disconnect()
		player:Destroy()
	end)

	it("fires for the ObjectValue-backed Character property", function()
		local player = PlayerMock.new()
		local character = Instance.new("Model")
		local fired = false
		-- Connected before any write, so the lazily-created backing must be the one a later write hits.
		local conn = PlayerMock.getPropertyChangedSignal(player, "Character"):Connect(function()
			fired = true
		end)

		PlayerMock.write(player, "Character", character)
		expect(fired).toBe(true)

		conn:Disconnect()
		character:Destroy()
		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.getPropertyChangedSignal(folder :: any, "AccountAge")
		end).toThrow()
		folder:Destroy()
	end)
end)

describe("PlayerMock.loadCharacterAsync", function()
	-- These tests pin the emulated lifecycle to the engine's avatar loading event ordering:
	-- https://devforum.roblox.com/t/avatar-loading-event-ordering-improvements/269607
	-- If that understanding is ever corrected, correct the emulation and these tests together.

	local function observeLifecycle(player: Player)
		local log = {}
		local maid = Maid.new()

		maid:GiveTask(PlayerMock.getSignal(player, "CharacterRemoving"):Connect(function(character)
			table.insert(
				log,
				string.format(
					"removing:%s current=%s parented=%s",
					character.Name,
					tostring(PlayerMock.read(player, "Character") == character),
					tostring(character.Parent ~= nil)
				)
			)
		end))
		maid:GiveTask(PlayerMock.getSignal(player, "CharacterAdded"):Connect(function(character)
			table.insert(
				log,
				string.format(
					"added:%s current=%s parent=%s",
					character.Name,
					tostring(PlayerMock.read(player, "Character") == character),
					tostring(character.Parent)
				)
			)
		end))
		maid:GiveTask(PlayerMock.getSignal(player, "CharacterAppearanceLoaded"):Connect(function(character)
			table.insert(
				log,
				string.format(
					"appearance:%s current=%s parent=%s",
					character.Name,
					tostring(PlayerMock.read(player, "Character") == character),
					tostring(character.Parent)
				)
			)
		end))
		maid:GiveTask(PlayerMock.getPropertyChangedSignal(player, "Character"):Connect(function()
			local character = PlayerMock.read(player, "Character")
			table.insert(log, "property:" .. (if character ~= nil then character.Name else "nil"))
		end))

		return log, maid
	end

	it("spawns: Character assigned, parented to Workspace, CharacterAdded, then CharacterAppearanceLoaded", function()
		local player = PlayerMock.new({ UserId = 1001 })
		local log, maid = observeLifecycle(player)

		local rig = Instance.new("Model")
		local character = PlayerMock.loadCharacterAsync(player, rig)

		expect(character).toBe(rig)
		expect(character.Name).toBe(player.Name) -- the engine names the character after the player
		-- The full announced order had completed by the time loadCharacterAsync returned
		expect(log).toEqual({
			"property:" .. player.Name,
			-- post-2019 ordering: CharacterAdded observes the character already in the Workspace
			"added:"
				.. player.Name
				.. " current=true parent=Workspace",
			-- CharacterAppearanceLoaded fires last, with the rig finalized and in the Workspace
			"appearance:"
				.. player.Name
				.. " current=true parent=Workspace",
		})

		maid:Destroy()
		character:Destroy()
		player:Destroy()
	end)

	it(
		"respawns: CharacterRemoving sees the old still current+parented; Character nils before the new assignment",
		function()
			local player = PlayerMock.new({ UserId = 1002 })
			local first = PlayerMock.loadCharacterAsync(player, Instance.new("Model"))

			local log, maid = observeLifecycle(player)
			local second = PlayerMock.loadCharacterAsync(player, Instance.new("Model"))

			expect(log).toEqual({
				"removing:" .. player.Name .. " current=true parented=true",
				"property:nil", -- Character nils when the old character is destroyed
				"property:" .. player.Name,
				"added:" .. player.Name .. " current=true parent=Workspace",
				"appearance:" .. player.Name .. " current=true parent=Workspace",
			})
			expect(first.Parent).toBeNil() -- old character was destroyed
			expect(second.Parent).toBe(workspace)

			maid:Destroy()
			second:Destroy()
			player:Destroy()
		end
	)

	it("does not fire CharacterAdded or CharacterAppearanceLoaded on a plain Character property write", function()
		-- Per the avatar loading announcement, these fire only during avatar loading,
		-- not whenever the Character property changes.
		local player = PlayerMock.new({ UserId = 1006 })
		local fired = {}
		local addedConn = PlayerMock.getSignal(player, "CharacterAdded"):Connect(function()
			table.insert(fired, "added")
		end)
		local appearanceConn = PlayerMock.getSignal(player, "CharacterAppearanceLoaded"):Connect(function()
			table.insert(fired, "appearance")
		end)

		local rig = Instance.new("Model")
		PlayerMock.write(player, "Character", rig)
		expect(fired).toEqual({})

		addedConn:Disconnect()
		appearanceConn:Disconnect()
		rig:Destroy()
		player:Destroy()
	end)

	it("builds a default R15 rig with a Humanoid when no model is given", function()
		local player = PlayerMock.new({ UserId = 1003 })
		local character = PlayerMock.loadCharacterAsync(player)

		expect(PlayerMock.read(player, "Character")).toBe(character)
		expect(character:FindFirstChildOfClass("Humanoid")).never.toBeNil()

		character:Destroy()
		player:Destroy()
	end)
end)

describe("PlayerMock.loadMinimalCharacterAsync", function()
	it("spawns a minimal rig with an anchored HumanoidRootPart as PrimaryPart and a Humanoid", function()
		local player = PlayerMock.new({ UserId = 1013 })
		local character = PlayerMock.loadMinimalCharacterAsync(player)

		expect(PlayerMock.read(player, "Character")).toBe(character)
		expect(character.Parent).toBe(workspace)

		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
		expect(rootPart).never.toBeNil()
		expect(rootPart.Anchored).toBe(true)
		expect(character.PrimaryPart).toBe(rootPart)
		expect(character:FindFirstChildOfClass("Humanoid")).never.toBeNil()

		character:Destroy()
		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.loadMinimalCharacterAsync(folder :: any)
		end).toThrow()
		folder:Destroy()
	end)
end)

describe("PlayerMock.getBackpack", function()
	it("is nil before the first spawn, like a real Player", function()
		local player = PlayerMock.new({ UserId = 1007 })
		expect(PlayerMock.getBackpack(player)).toBeNil()
		player:Destroy()
	end)

	it("resolves a genuine Backpack instance named 'Backpack' after a spawn", function()
		local player = PlayerMock.new({ UserId = 1008 })
		local character = PlayerMock.loadCharacterAsync(player, Instance.new("Model"))

		local backpack = PlayerMock.getBackpack(player)
		expect(backpack).never.toBeNil()
		expect((backpack :: Backpack):IsA("Backpack")).toBe(true)
		expect((backpack :: Backpack).Name).toBe("Backpack")
		expect((backpack :: Backpack).Parent).toBe(player)

		character:Destroy()
		player:Destroy()
	end)

	it("is replaced with a fresh empty Backpack on respawn, and the old one is destroyed", function()
		local player = PlayerMock.new({ UserId = 1009 })
		PlayerMock.loadCharacterAsync(player, Instance.new("Model"))

		local first = assert(PlayerMock.getBackpack(player))
		local tool = Instance.new("Tool")
		tool.RequiresHandle = false
		tool.Parent = first

		local character = PlayerMock.loadCharacterAsync(player, Instance.new("Model"))

		local second = assert(PlayerMock.getBackpack(player))
		expect(second).never.toBe(first)
		expect(first.Parent).toBeNil() -- old backpack (and its contents) destroyed with the respawn
		expect(#second:GetChildren()).toBe(0)

		character:Destroy()
		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.getBackpack(folder :: any)
		end).toThrow()
		folder:Destroy()
	end)
end)

describe("PlayerMock.getStarterGear", function()
	it("is nil before the first spawn, like a real Player", function()
		local player = PlayerMock.new({ UserId = 1014 })
		expect(PlayerMock.getStarterGear(player)).toBeNil()
		player:Destroy()
	end)

	it("resolves a genuine StarterGear instance named 'StarterGear' after a spawn", function()
		local player = PlayerMock.new({ UserId = 1015 })
		local character = PlayerMock.loadCharacterAsync(player, Instance.new("Model"))

		local starterGear = PlayerMock.getStarterGear(player)
		expect(starterGear).never.toBeNil()
		expect((starterGear :: StarterGear):IsA("StarterGear")).toBe(true)
		expect((starterGear :: StarterGear).Name).toBe("StarterGear")
		expect((starterGear :: StarterGear).Parent).toBe(player)

		character:Destroy()
		player:Destroy()
	end)

	it("persists the same StarterGear (and its contents) across a respawn, unlike the Backpack", function()
		local player = PlayerMock.new({ UserId = 1016 })
		PlayerMock.loadCharacterAsync(player, Instance.new("Model"))

		local first = assert(PlayerMock.getStarterGear(player))
		local tool = Instance.new("Tool")
		tool.RequiresHandle = false
		tool.Parent = first

		local character = PlayerMock.loadCharacterAsync(player, Instance.new("Model"))

		local second = assert(PlayerMock.getStarterGear(player))
		expect(second).toBe(first)
		expect(second:FindFirstChildOfClass("Tool")).toBe(tool)

		character:Destroy()
		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.getStarterGear(folder :: any)
		end).toThrow()
		folder:Destroy()
	end)
end)

describe("PlayerMock.removeCharacter", function()
	it(
		"despawns: CharacterRemoving sees the character still current, then Character nils, then it is destroyed",
		function()
			local player = PlayerMock.new({ UserId = 1004 })
			local character = PlayerMock.loadCharacterAsync(player, Instance.new("Model"))

			local log = {}
			local removingConn = PlayerMock.getSignal(player, "CharacterRemoving"):Connect(function(removing)
				table.insert(
					log,
					string.format(
						"removing current=%s parented=%s",
						tostring(PlayerMock.read(player, "Character") == removing),
						tostring(removing.Parent ~= nil)
					)
				)
			end)
			local propertyConn = PlayerMock.getPropertyChangedSignal(player, "Character"):Connect(function()
				local current = PlayerMock.read(player, "Character")
				-- Character nils while the model still exists, so observers tear down before destruction
				table.insert(
					log,
					string.format("property=%s destroyed=%s", tostring(current), tostring(character.Parent == nil))
				)
			end)

			PlayerMock.removeCharacter(player)

			expect(log).toEqual({
				"removing current=true parented=true",
				"property=nil destroyed=false",
			})
			expect(character.Parent).toBeNil()

			removingConn:Disconnect()
			propertyConn:Disconnect()
			player:Destroy()
		end
	)

	it("is a no-op when no character is loaded", function()
		local player = PlayerMock.new({ UserId = 1005 })
		local fired = false
		local conn = PlayerMock.getSignal(player, "CharacterRemoving"):Connect(function()
			fired = true
		end)

		PlayerMock.removeCharacter(player)
		expect(fired).toBe(false)

		conn:Disconnect()
		player:Destroy()
	end)
end)

describe("PlayerMock.kick", function()
	it("records the message and removes the mock from the game, like the engine removing a kicked player", function()
		local player = PlayerMock.new({ UserId = 2001 })
		player.Parent = workspace

		local ancestryChangedFired = false
		local conn = PlayerMock.getSignal(player, "AncestryChanged"):Connect(function()
			ancestryChangedFired = true
		end)

		PlayerMock.kick(player, "You are banned")

		expect(PlayerMock.getKickMessage(player)).toBe("You are banned")
		expect(ancestryChangedFired).toBe(true)
		expect(player.Parent).toBeNil()

		conn:Disconnect()
		player:Destroy()
	end)

	it("removes the character while the mock is still in the game, before the mock is destroyed", function()
		local player = PlayerMock.new({ UserId = 2002 })
		player.Parent = workspace
		local character = PlayerMock.loadCharacterAsync(player, Instance.new("Model"))

		local log = {}
		local conn = PlayerMock.getSignal(player, "CharacterRemoving"):Connect(function(removing)
			table.insert(
				log,
				string.format(
					"removing current=%s mockParented=%s",
					tostring(PlayerMock.read(player, "Character") == removing),
					tostring(player.Parent ~= nil)
				)
			)
		end)

		PlayerMock.kick(player, "You are banned")

		expect(log).toEqual({ "removing current=true mockParented=true" })
		expect(character.Parent).toBeNil()
		expect(player.Parent).toBeNil()

		conn:Disconnect()
	end)

	it("records an empty message for a messageless kick", function()
		local player = PlayerMock.new({ UserId = 2003 })
		PlayerMock.kick(player)
		expect(PlayerMock.getKickMessage(player)).toBe("")
	end)

	it("throws on a non-string message", function()
		local player = PlayerMock.new({ UserId = 2004 })
		expect(function()
			PlayerMock.kick(player, 5 :: any)
		end).toThrow()
		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.kick(folder :: any, "nope")
		end).toThrow()
		folder:Destroy()
	end)
end)

describe("PlayerMock.getKickMessage", function()
	it("returns nil when the mock was never kicked", function()
		local player = PlayerMock.new({ UserId = 2005 })
		expect(PlayerMock.getKickMessage(player)).toBeNil()
		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.getKickMessage(folder :: any)
		end).toThrow()
		folder:Destroy()
	end)
end)

describe("PlayerMock.readLookup", function()
	it("returns the pre-authored default for an uninjected lookup", function()
		local player = PlayerMock.new({ UserId = 12345 })
		local groupResult = PlayerMock.readLookup(player, "GroupService.GetRolesInGroupAsync", 372)
		expect(groupResult.IsMember).toBe(false)
		expect(groupResult.Roles).toEqual({})
		expect(PlayerMock.readLookup(player, "GroupService.GetGroupsAsync", 0)).toEqual({})
		expect(PlayerMock.readLookup(player, "MarketplaceService.UserOwnsGamePassAsync", 111)).toBe(false)
		player:Destroy()
	end)

	it("keys results independently per ID within a domain", function()
		local player = PlayerMock.new({ UserId = 12345 })
		PlayerMock.writeLookup(player, "GroupService.GetRolesInGroupAsync", 372, {
			IsMember = true,
			Roles = { { Name = "Admin", Rank = 230 } },
		})

		expect(PlayerMock.readLookup(player, "GroupService.GetRolesInGroupAsync", 372).IsMember).toBe(true)
		expect(PlayerMock.readLookup(player, "GroupService.GetRolesInGroupAsync", 999).IsMember).toBe(false)

		player:Destroy()
	end)

	it("keys results independently across domains sharing an ID space", function()
		local player = PlayerMock.new({ UserId = 12345 })
		-- PlayerOwnsAsset (inventory) and PlayerOwnsAssetAsync (paid access) are distinct engine calls.
		PlayerMock.writeLookup(player, "MarketplaceService.PlayerOwnsAsset", 555, true)

		expect(PlayerMock.readLookup(player, "MarketplaceService.PlayerOwnsAsset", 555)).toBe(true)
		expect(PlayerMock.readLookup(player, "MarketplaceService.PlayerOwnsAssetAsync", 555)).toBe(false)

		player:Destroy()
	end)

	it("defaults an EnumItem-keyed effect domain to the engine's initial state", function()
		local player = PlayerMock.new()
		expect(PlayerMock.readLookup(player, "StarterGui.SetCoreGuiEnabled", Enum.CoreGuiType.Backpack)).toBe(true)
		player:Destroy()
	end)

	it("errors on a number key for an EnumItem-keyed domain", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.readLookup(player, "StarterGui.SetCoreGuiEnabled", 1)
		end).toThrow()
		player:Destroy()
	end)

	it("errors on an EnumItem key for a number-keyed domain", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.readLookup(player, "MarketplaceService.UserOwnsGamePassAsync", Enum.CoreGuiType.Backpack :: any)
		end).toThrow()
		player:Destroy()
	end)

	it("defaults a string-keyed domain to the pre-authored default", function()
		local player = PlayerMock.new({ UserId = 12345 })
		local status = PlayerMock.readLookup(player, "MarketplaceService.GetUserSubscriptionStatusAsync", "EXP-123")
		expect(status.IsSubscribed).toBe(false)
		expect(status.IsRenewing).toBe(false)
		player:Destroy()
	end)

	it("errors on a number key for a string-keyed domain", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.readLookup(player, "MarketplaceService.GetUserSubscriptionStatusAsync", 123)
		end).toThrow()
		player:Destroy()
	end)

	it("errors on an empty-string key for a string-keyed domain", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.readLookup(player, "MarketplaceService.GetUserSubscriptionStatusAsync", "")
		end).toThrow()
		player:Destroy()
	end)

	it("errors on an unknown lookup domain", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.readLookup(player, "GroupService.GetRankInGroup", 372)
		end).toThrow()
		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.readLookup(folder :: any, "GroupService.GetRolesInGroupAsync", 372)
		end).toThrow()
		folder:Destroy()
	end)
end)

describe("PlayerMock.writeLookup", function()
	it("injects a value every subsequent read resolves", function()
		local player = PlayerMock.new({ UserId = 12345 })
		PlayerMock.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", 111, true)

		expect(PlayerMock.readLookup(player, "MarketplaceService.UserOwnsGamePassAsync", 111)).toBe(true)
		expect(PlayerMock.readLookup(player, "MarketplaceService.UserOwnsGamePassAsync", 111)).toBe(true)

		player:Destroy()
	end)

	it("round-trips a table-valued result through its backing attribute", function()
		local player = PlayerMock.new({ UserId = 12345 })
		PlayerMock.writeLookup(player, "GroupService.GetRolesInGroupAsync", 372, {
			IsMember = true,
			Roles = { { Name = "Moderator", Rank = 150 } },
		})

		local result = PlayerMock.readLookup(player, "GroupService.GetRolesInGroupAsync", 372)
		expect(result.IsMember).toBe(true)
		expect(result.Roles).toEqual({ { Name = "Moderator", Rank = 150 } })

		player:Destroy()
	end)

	it("clears back to the default with nil", function()
		local player = PlayerMock.new({ UserId = 12345 })
		PlayerMock.writeLookup(player, "GroupService.GetRolesInGroupAsync", 372, {
			IsMember = true,
			Roles = { { Name = "Admin", Rank = 230 } },
		})
		PlayerMock.writeLookup(player, "GroupService.GetRolesInGroupAsync", 372, nil)

		expect(PlayerMock.readLookup(player, "GroupService.GetRolesInGroupAsync", 372).IsMember).toBe(false)

		player:Destroy()
	end)

	it("fires GetAttributeChangedSignal on the backing attribute", function()
		local player = PlayerMock.new()
		local fired = false
		local conn = player
			:GetAttributeChangedSignal("PlayerMockLookup_MarketplaceService_UserOwnsGamePassAsync_111")
			:Connect(function()
				fired = true
			end)

		PlayerMock.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", 111, true)
		expect(fired).toBe(true)

		conn:Disconnect()
		player:Destroy()
	end)

	it("round-trips an EnumItem-keyed effect write, keyed per enum value", function()
		local player = PlayerMock.new()
		PlayerMock.writeLookup(player, "StarterGui.SetCoreGuiEnabled", Enum.CoreGuiType.Backpack, false)

		expect(PlayerMock.readLookup(player, "StarterGui.SetCoreGuiEnabled", Enum.CoreGuiType.Backpack)).toBe(false)
		expect(PlayerMock.readLookup(player, "StarterGui.SetCoreGuiEnabled", Enum.CoreGuiType.Chat)).toBe(true)

		PlayerMock.writeLookup(player, "StarterGui.SetCoreGuiEnabled", Enum.CoreGuiType.Backpack, nil)
		expect(PlayerMock.readLookup(player, "StarterGui.SetCoreGuiEnabled", Enum.CoreGuiType.Backpack)).toBe(true)

		player:Destroy()
	end)

	it("round-trips a string-keyed result, keyed per subscriptionId", function()
		local player = PlayerMock.new({ UserId = 12345 })
		PlayerMock.writeLookup(player, "MarketplaceService.GetUserSubscriptionStatusAsync", "EXP-123", {
			IsSubscribed = true,
			IsRenewing = false,
		})

		local status = PlayerMock.readLookup(player, "MarketplaceService.GetUserSubscriptionStatusAsync", "EXP-123")
		expect(status.IsSubscribed).toBe(true)
		expect(status.IsRenewing).toBe(false)
		expect(
			PlayerMock.readLookup(player, "MarketplaceService.GetUserSubscriptionStatusAsync", "EXP-999").IsSubscribed
		).toBe(false)

		PlayerMock.writeLookup(player, "MarketplaceService.GetUserSubscriptionStatusAsync", "EXP-123", nil)
		expect(
			PlayerMock.readLookup(player, "MarketplaceService.GetUserSubscriptionStatusAsync", "EXP-123").IsSubscribed
		).toBe(false)

		player:Destroy()
	end)

	it("errors when a string-keyed table value fails the domain's shape validation", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.writeLookup(
				player,
				"MarketplaceService.GetUserSubscriptionStatusAsync",
				"EXP-123",
				{
					IsSubscribed = "yes",
				} :: any
			)
		end).toThrow()
		player:Destroy()
	end)

	it("errors when the value does not match the domain's value type", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", 111, "yes" :: any)
		end).toThrow()
		player:Destroy()
	end)

	it("errors when a table-valued result fails the domain's shape check", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.writeLookup(player, "GroupService.GetRolesInGroupAsync", 372, {
				IsMember = true,
				Roles = { { Name = "Admin", Rank = "admin" } },
			})
		end).toThrow()
		player:Destroy()
	end)

	it("errors on an unknown lookup domain", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.writeLookup(player, "GroupService.GetRankInGroup", 372, 230)
		end).toThrow()
		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.writeLookup(folder :: any, "MarketplaceService.UserOwnsGamePassAsync", 111, true)
		end).toThrow()
		folder:Destroy()
	end)
end)

describe("PlayerMock friends domains", function()
	it("defaults the friends list to empty", function()
		local player = PlayerMock.new({ UserId = 90031001 })
		expect(PlayerMock.readLookup(player, "Players.GetFriendsAsync", 0)).toEqual({})
		player:Destroy()
	end)

	it("round-trips an injected friends list", function()
		local player = PlayerMock.new({ UserId = 90031002 })
		PlayerMock.writeLookup(player, "Players.GetFriendsAsync", 0, {
			{ Id = 90031003, Username = "friend_one", DisplayName = "Friend One", IsOnline = true },
			{ Id = 90031004, Username = "friend_two", DisplayName = "Friend Two", IsOnline = false },
		})

		local friends = PlayerMock.readLookup(player, "Players.GetFriendsAsync", 0)
		expect(#friends).toBe(2)
		expect(friends[1].Username).toBe("friend_one")
		expect(friends[2].IsOnline).toBe(false)

		player:Destroy()
	end)

	it("errors when a friends entry fails the FriendData shape check", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.writeLookup(player, "Players.GetFriendsAsync", 0, {
				{ Id = 90031005, Username = "no_online_flag", DisplayName = "Nope" },
			})
		end).toThrow()
		player:Destroy()
	end)

	it("defaults friendship to false, keyed per other UserId", function()
		local player = PlayerMock.new({ UserId = 90031006 })
		expect(PlayerMock.readLookup(player, "Player.IsFriendsWithAsync", 90031007)).toBe(false)

		PlayerMock.writeLookup(player, "Player.IsFriendsWithAsync", 90031007, true)
		expect(PlayerMock.readLookup(player, "Player.IsFriendsWithAsync", 90031007)).toBe(true)
		expect(PlayerMock.readLookup(player, "Player.IsFriendsWithAsync", 90031008)).toBe(false)

		player:Destroy()
	end)
end)

describe("PlayerMock user info domain", function()
	it("derives the default from the mock's own identity", function()
		local player = PlayerMock.new({ UserId = 90032001, DisplayName = "Display Name", HasVerifiedBadge = true })

		local userInfo = PlayerMock.readLookup(player, "UserService.GetUserInfosByUserIdsAsync", 0)
		expect(userInfo.Id).toBe(90032001)
		expect(userInfo.Username).toBe(player.Name)
		expect(userInfo.DisplayName).toBe("Display Name")
		expect(userInfo.HasVerifiedBadge).toBe(true)

		player:Destroy()
	end)

	it("tracks later property writes while unset, so identity cannot tear", function()
		local player = PlayerMock.new({ UserId = 90032002 })
		PlayerMock.write(player, "DisplayName", "Renamed")

		expect(PlayerMock.readLookup(player, "UserService.GetUserInfosByUserIdsAsync", 0).DisplayName).toBe("Renamed")

		player:Destroy()
	end)

	it("resolves an injected user info over the derived default", function()
		local player = PlayerMock.new({ UserId = 90032003 })
		PlayerMock.writeLookup(player, "UserService.GetUserInfosByUserIdsAsync", 0, {
			Id = 90032003,
			Username = "injected_name",
			DisplayName = "Injected",
			HasVerifiedBadge = false,
		})

		local userInfo = PlayerMock.readLookup(player, "UserService.GetUserInfosByUserIdsAsync", 0)
		expect(userInfo.Username).toBe("injected_name")

		PlayerMock.writeLookup(player, "UserService.GetUserInfosByUserIdsAsync", 0, nil)
		expect(PlayerMock.readLookup(player, "UserService.GetUserInfosByUserIdsAsync", 0).Username).toBe(player.Name)

		player:Destroy()
	end)

	it("errors when the injected value fails the UserInfo shape check", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.writeLookup(
				player,
				"UserService.GetUserInfosByUserIdsAsync",
				0,
				{
					Id = 1,
					Username = "missing_fields",
				} :: any
			)
		end).toThrow()
		player:Destroy()
	end)
end)

describe("PlayerMock.getMockByUsername", function()
	it("resolves a parented mock by its default Name-derived username", function()
		local player = PlayerMock.new({ UserId = 90033001 })
		player.Parent = Workspace

		expect(PlayerMock.getMockByUsername(player.Name)).toBe(player)
		player:Destroy()
	end)

	it("resolves a parented mock by an injected username", function()
		local player = PlayerMock.new({ UserId = 90033002 })
		player.Parent = Workspace
		PlayerMock.writeLookup(player, "UserService.GetUserInfosByUserIdsAsync", 0, {
			Id = 90033002,
			Username = "injected_username",
			DisplayName = "Injected",
			HasVerifiedBadge = false,
		})

		expect(PlayerMock.getMockByUsername("injected_username")).toBe(player)
		player:Destroy()
	end)

	it("returns nil when no mock matches", function()
		local player = PlayerMock.new({ UserId = 90033003 })
		player.Parent = Workspace

		expect(PlayerMock.getMockByUsername("no_such_username")).toBeNil()
		player:Destroy()
	end)

	it("returns nil for an unparented mock, like the engine's DataModel-scoped resolve", function()
		local player = PlayerMock.new({ UserId = 90033004 })

		expect(PlayerMock.getMockByUsername(player.Name)).toBeNil()
		player:Destroy()
	end)

	it("throws on a non-string username", function()
		expect(function()
			PlayerMock.getMockByUsername(12345 :: any)
		end).toThrow()
	end)
end)

describe("PlayerMock.getLookupChangedSignal", function()
	it("fires when the lookup is written, keyed per ID", function()
		local player = PlayerMock.new({ UserId = 90034001 })
		local fired = 0
		local conn = PlayerMock.getLookupChangedSignal(player, "Player.IsFriendsWithAsync", 90034002):Connect(function()
			fired += 1
		end)

		PlayerMock.writeLookup(player, "Player.IsFriendsWithAsync", 90034003, true)
		expect(fired).toBe(0)

		PlayerMock.writeLookup(player, "Player.IsFriendsWithAsync", 90034002, true)
		expect(fired).toBe(1)

		conn:Disconnect()
		player:Destroy()
	end)

	it("errors on an unknown lookup domain", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.getLookupChangedSignal(player, "Players.GetFriends", 0)
		end).toThrow()
		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.getLookupChangedSignal(folder :: any, "Player.IsFriendsWithAsync", 1)
		end).toThrow()
		folder:Destroy()
	end)
end)

describe("PlayerMock.getSignal", function()
	it("delivers fireSignal arguments to a connected handler", function()
		local player = PlayerMock.new()
		local messages = {}
		local conn = PlayerMock.getSignal(player, "Chatted"):Connect(function(message, recipient)
			table.insert(messages, { message = message, recipient = recipient })
		end)

		PlayerMock.fireSignal(player, "Chatted", "hello", player)

		expect(#messages).toBe(1)
		expect(messages[1].message).toBe("hello")
		expect(messages[1].recipient).toBe(player)

		conn:Disconnect()
		player:Destroy()
	end)

	it("returns the same backing signal across calls", function()
		local player = PlayerMock.new()
		local count = 0
		local conn = PlayerMock.getSignal(player, "Idled"):Connect(function()
			count += 1
		end)

		-- A second lookup must not create a second backing signal the fire misses.
		PlayerMock.getSignal(player, "Idled")
		PlayerMock.fireSignal(player, "Idled", 5)

		expect(count).toBe(1)

		conn:Disconnect()
		player:Destroy()
	end)

	it("returns the genuine native signal for an event inherited from Instance", function()
		local player = PlayerMock.new()
		local fired = false
		local conn = PlayerMock.getSignal(player, "Destroying"):Connect(function()
			fired = true
		end)

		player:Destroy()

		expect(fired).toBe(true)
		conn:Disconnect()
	end)

	it("errors on a misspelled event name", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.getSignal(player, "Chattd")
		end).toThrow()
		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.getSignal(folder :: any, "Chatted")
		end).toThrow()
		folder:Destroy()
	end)
end)

describe("PlayerMock.fireSignal", function()
	it("errors on a misspelled event name", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.fireSignal(player, "Chattd", "hello")
		end).toThrow()
		player:Destroy()
	end)

	it("errors on an inherited native event only the engine can fire", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.fireSignal(player, "Destroying")
		end).toThrow()
		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.fireSignal(folder :: any, "Chatted", "hello")
		end).toThrow()
		folder:Destroy()
	end)
end)

describe("PlayerMock.bindInput", function()
	it("dispatches a bound action with the engine's argument order and returns its result", function()
		local player = PlayerMock.new()
		local seenActionName, seenInputState, seenInputObject
		PlayerMock.bindInput(
			player,
			"ContextActionService.BindAction",
			"Drag",
			function(actionName, userInputState, inputObject)
				seenActionName = actionName
				seenInputState = userInputState
				seenInputObject = inputObject
				return Enum.ContextActionResult.Pass
			end,
			false,
			Enum.UserInputType.MouseButton2
		)

		local result = PlayerMock.fireInput(player, "Drag", Enum.UserInputState.Begin, { Position = Vector3.zero })

		expect(result).toBe(Enum.ContextActionResult.Pass)
		expect(seenActionName).toBe("Drag")
		expect(seenInputState).toBe(Enum.UserInputState.Begin)
		expect(seenInputObject).toEqual({ Position = Vector3.zero })

		player:Destroy()
	end)

	it("replaces the callback when a name is rebound", function()
		local player = PlayerMock.new()
		local firedFirst = false
		local firedSecond = false
		PlayerMock.bindInput(player, "ContextActionService.BindAction", "Drag", function()
			firedFirst = true
			return nil
		end, false)
		PlayerMock.bindInput(player, "ContextActionService.BindAction", "Drag", function()
			firedSecond = true
			return nil
		end, false)

		PlayerMock.fireInput(player, "Drag", Enum.UserInputState.Begin)

		expect(firedFirst).toBe(false)
		expect(firedSecond).toBe(true)

		player:Destroy()
	end)

	it("binds at priority into the same action registry", function()
		local player = PlayerMock.new()
		local fired = false
		PlayerMock.bindInput(player, "ContextActionService.BindActionAtPriority", "Sprint", function()
			fired = true
			return nil
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift)

		expect(PlayerMock.isInputBound(player, "Sprint")).toBe(true)
		PlayerMock.fireInput(player, "Sprint", Enum.UserInputState.Begin)
		expect(fired).toBe(true)

		player:Destroy()
	end)

	it("errors when a priority bind omits its priority", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.bindInput(player, "ContextActionService.BindActionAtPriority", "Sprint", function()
				return nil
			end, false)
		end).toThrow()
		player:Destroy()
	end)

	it("unbinds through the UnbindAction domain so the action no longer reads bound", function()
		local player = PlayerMock.new()
		PlayerMock.bindInput(player, "ContextActionService.BindAction", "Drag", function()
			return nil
		end, false)
		expect(PlayerMock.isInputBound(player, "Drag")).toBe(true)

		PlayerMock.bindInput(player, "ContextActionService.UnbindAction", "Drag")
		expect(PlayerMock.isInputBound(player, "Drag")).toBe(false)

		player:Destroy()
	end)

	it("unbinding an unbound action is a no-op, like the engine call", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.bindInput(player, "ContextActionService.UnbindAction", "NeverBound")
		end).never.toThrow()
		player:Destroy()
	end)

	it("errors on an unknown input domain", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.bindInput(player, "ContextActionService.BindActoin", "Drag", function()
				return nil
			end, false)
		end).toThrow()
		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.bindInput(folder :: any, "ContextActionService.BindAction", "Drag", function()
				return nil
			end, false)
		end).toThrow()
		folder:Destroy()
	end)
end)

describe("PlayerMock.fireInput", function()
	it("errors on an unbound action", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.fireInput(player, "NeverBound", Enum.UserInputState.Begin)
		end).toThrow()
		player:Destroy()
	end)

	it("errors after the action is unbound", function()
		local player = PlayerMock.new()
		PlayerMock.bindInput(player, "ContextActionService.BindAction", "Drag", function()
			return nil
		end, false)
		PlayerMock.bindInput(player, "ContextActionService.UnbindAction", "Drag")

		expect(function()
			PlayerMock.fireInput(player, "Drag", Enum.UserInputState.Begin)
		end).toThrow()

		player:Destroy()
	end)

	it("errors on a non-UserInputState state", function()
		local player = PlayerMock.new()
		PlayerMock.bindInput(player, "ContextActionService.BindAction", "Drag", function()
			return nil
		end, false)

		expect(function()
			PlayerMock.fireInput(player, "Drag", Enum.ContextActionResult.Pass :: any)
		end).toThrow()

		player:Destroy()
	end)

	it("passes the inputObject by reference, so a stand-in's methods survive", function()
		local player = PlayerMock.new()
		local seenInput
		PlayerMock.bindInput(player, "ContextActionService.BindAction", "Fire", function(_name, _state, inputObject)
			seenInput = inputObject
			return nil
		end, false)

		local input = PlayerMock.makeInputObject({
			UserInputType = Enum.UserInputType.Gamepad1,
			KeyCode = Enum.KeyCode.ButtonA,
		})
		PlayerMock.fireInput(player, "Fire", Enum.UserInputState.Begin, input)

		-- Same object (not a bindable copy): the method a handler needs is still callable.
		expect(seenInput).toBe(input)
		expect(typeof(seenInput:GetPropertyChangedSignal("UserInputState"))).toBe("table")

		player:Destroy()
	end)
end)

describe("PlayerMock.makeInputObject", function()
	it("exposes the read fields with sensible defaults", function()
		local input = PlayerMock.makeInputObject({
			UserInputType = Enum.UserInputType.Gamepad1,
			KeyCode = Enum.KeyCode.ButtonA,
		})

		expect(input.UserInputType).toBe(Enum.UserInputType.Gamepad1)
		expect(input.KeyCode).toBe(Enum.KeyCode.ButtonA)
		expect(input.UserInputState).toBe(Enum.UserInputState.Begin)
		expect(input.Position).toBe(Vector3.zero)
	end)

	it("fires GetPropertyChangedSignal('UserInputState') on SetUserInputState", function()
		local input = PlayerMock.makeInputObject({ UserInputType = Enum.UserInputType.Gamepad1 })

		local fired = 0
		local connection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			fired += 1
		end)

		input:SetUserInputState(Enum.UserInputState.End)

		expect(fired).toBe(1)
		expect(input.UserInputState).toBe(Enum.UserInputState.End)

		connection:Disconnect()
	end)

	it("returns the same signal per property and rejects a bad UserInputType", function()
		local input = PlayerMock.makeInputObject()
		expect(input:GetPropertyChangedSignal("UserInputState")).toBe(input:GetPropertyChangedSignal("UserInputState"))
		expect(function()
			PlayerMock.makeInputObject({ UserInputType = Enum.KeyCode.ButtonA :: any })
		end).toThrow()
	end)
end)

describe("PlayerMock selected GUI object", function()
	it("defaults to nil and round-trips a set value", function()
		local player = PlayerMock.new()
		local screenGui = Instance.new("ScreenGui")
		local frame = Instance.new("Frame")
		frame.Parent = screenGui

		expect(PlayerMock.getSelectedGuiObject(player)).toBeNil()

		PlayerMock.setSelectedGuiObject(player, frame)
		expect(PlayerMock.getSelectedGuiObject(player)).toBe(frame)

		PlayerMock.setSelectedGuiObject(player, nil)
		expect(PlayerMock.getSelectedGuiObject(player)).toBeNil()

		screenGui:Destroy()
		player:Destroy()
	end)

	it("fires the changed signal when the selection moves", function()
		local player = PlayerMock.new()
		local screenGui = Instance.new("ScreenGui")
		local frame = Instance.new("Frame")
		frame.Parent = screenGui

		local fired = 0
		local connection = PlayerMock.getSelectedGuiObjectChangedSignal(player):Connect(function()
			fired += 1
		end)

		PlayerMock.setSelectedGuiObject(player, frame)
		expect(fired).toBe(1)

		connection:Disconnect()
		screenGui:Destroy()
		player:Destroy()
	end)

	it("rejects a non-GuiObject and a non-mock", function()
		local player = PlayerMock.new()
		expect(function()
			PlayerMock.setSelectedGuiObject(player, Instance.new("Folder") :: any)
		end).toThrow()

		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.getSelectedGuiObject(folder :: any)
		end).toThrow()
		folder:Destroy()

		player:Destroy()
	end)
end)

describe("PlayerMock local player", function()
	afterEach(function()
		PlayerMock.setMockedLocalPlayer(nil)
	end)

	it("returns the designated mock", function()
		local player = PlayerMock.new({ UserId = 1 })
		player.Parent = workspace -- GetTagged only resolves parented instances
		PlayerMock.setMockedLocalPlayer(player)

		expect(PlayerMock.getMockedLocalPlayer()).toBe(player)

		player:Destroy()
	end)

	it("clears the designation with nil", function()
		local player = PlayerMock.new({ UserId = 1 })
		player.Parent = workspace
		PlayerMock.setMockedLocalPlayer(player)
		PlayerMock.setMockedLocalPlayer(nil)

		expect(PlayerMock.getMockedLocalPlayer()).toBeNil()

		player:Destroy()
	end)

	it("asserts on a non-mock designation", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.setMockedLocalPlayer(folder :: any)
		end).toThrow()
		folder:Destroy()
	end)
end)

describe("PlayerMock.getPlayerGui", function()
	it("carries a PlayerGui stand-in from construction", function()
		local player = PlayerMock.new()

		local playerGui = PlayerMock.getPlayerGui(player)
		expect(typeof(playerGui)).toBe("Instance")
		expect((playerGui :: Instance).Name).toBe("PlayerGui")
		expect((playerGui :: Instance).Parent).toBe(player)

		player:Destroy()
	end)

	it("accepts parented gui surfaces", function()
		local player = PlayerMock.new()

		local screenGui = Instance.new("ScreenGui")
		screenGui.Parent = PlayerMock.getPlayerGui(player)
		expect(screenGui.Parent).toBe(PlayerMock.getPlayerGui(player))

		player:Destroy()
	end)

	it("is destroyed with the mock", function()
		local player = PlayerMock.new()
		local playerGui = PlayerMock.getPlayerGui(player)

		player:Destroy()

		expect(playerGui.Parent).toBeNil()
	end)

	it("asserts on a non-mock", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.getPlayerGui(folder :: any)
		end).toThrow()
		folder:Destroy()
	end)
end)

describe("PlayerMock.getPlayerScripts", function()
	it("carries a PlayerScripts stand-in from construction", function()
		local player = PlayerMock.new()

		local playerScripts = PlayerMock.getPlayerScripts(player)
		expect(typeof(playerScripts)).toBe("Instance")
		expect((playerScripts :: Instance).Name).toBe("PlayerScripts")
		expect((playerScripts :: Instance).Parent).toBe(player)

		player:Destroy()
	end)

	it("accepts parented script stand-ins", function()
		local player = PlayerMock.new()

		local localScript = Instance.new("LocalScript")
		localScript.Name = "RbxCharacterSounds"
		localScript.Parent = PlayerMock.getPlayerScripts(player)
		expect(localScript.Parent).toBe(PlayerMock.getPlayerScripts(player))

		player:Destroy()
	end)

	it("is destroyed with the mock", function()
		local player = PlayerMock.new()
		local playerScripts = PlayerMock.getPlayerScripts(player)

		player:Destroy()

		expect(playerScripts.Parent).toBeNil()
	end)

	it("asserts on a non-mock", function()
		local folder = Instance.new("Folder")
		expect(function()
			PlayerMock.getPlayerScripts(folder :: any)
		end).toThrow()
		folder:Destroy()
	end)
end)
