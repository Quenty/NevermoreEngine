--!strict
--[[
	@class PlayerMockMethodUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PlayerMockMethodUtils = require("PlayerMockMethodUtils")
local PlayerMockPropertyUtils = require("PlayerMockPropertyUtils")
local PlayerMockReplicationFocusUtils = require("PlayerMockReplicationFocusUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PlayerMockMethodUtils.getKickMessage", function()
	it("is nil for a mock that was never kicked", function()
		local player = PlayerMock.new()

		expect(PlayerMockMethodUtils.getKickMessage(player)).toBeNil()

		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")

		expect(function()
			PlayerMockMethodUtils.getKickMessage(folder :: any)
		end).toThrow()

		folder:Destroy()
	end)
end)

describe("PlayerMockMethodUtils.call Player.Kick", function()
	it("records the message", function()
		local player = PlayerMock.new()
		PlayerMockMethodUtils.call(player, "Player.Kick", "Go away")

		expect(PlayerMockMethodUtils.getKickMessage(player)).toBe("Go away")

		player:Destroy()
	end)

	it("records an empty message when none is given", function()
		local player = PlayerMock.new()
		PlayerMockMethodUtils.call(player, "Player.Kick")

		expect(PlayerMockMethodUtils.getKickMessage(player)).toBe("")

		player:Destroy()
	end)

	it("removes the mock from the DataModel, like a player leaving", function()
		local player = PlayerMock.new()
		player.Parent = Workspace

		PlayerMockMethodUtils.call(player, "Player.Kick")

		expect(player.Parent).toBeNil()

		player:Destroy()
	end)

	it("removes the character before the mock leaves, so CharacterRemoving sees a live mock", function()
		local player = PlayerMock.new()
		player.Parent = Workspace

		local character = Instance.new("Model")
		PlayerMockPropertyUtils.write(player, "Character", character)

		local parentWhenRemoving
		local connection = PlayerMockPropertyUtils.getPropertyChangedSignal(player, "Character"):Connect(function()
			parentWhenRemoving = player.Parent
		end)

		PlayerMockMethodUtils.call(player, "Player.Kick")

		expect(parentWhenRemoving).toBe(Workspace)
		expect(PlayerMockPropertyUtils.read(player, "Character")).toBeNil()

		connection:Disconnect()
		player:Destroy()
	end)

	it("throws on a non-string message", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockMethodUtils.call(player, "Player.Kick", 5 :: any)
		end).toThrow()

		player:Destroy()
	end)
end)

describe("PlayerMockMethodUtils method domains", function()
	it("names a real member of a real class for every domain it models", function()
		local unreflected = {}

		for _, domainPath in PlayerMockMethodUtils._getMethodDomains() do
			if not PlayerMockMethodUtils._isMethod(domainPath) then
				table.insert(unreflected, domainPath)
			end
		end

		expect(unreflected).toEqual({})
	end)

	it("models every method the facade calls through", function()
		local domains = PlayerMockMethodUtils._getMethodDomains()
		local modelled = {}
		for _, domainPath in domains do
			modelled[domainPath] = true
		end

		expect(modelled["Player.Kick"]).toBe(true)
		expect(modelled["Player.AddReplicationFocus"]).toBe(true)
		expect(modelled["Player.RemoveReplicationFocus"]).toBe(true)
		expect(modelled["ContextActionService.BindAction"]).toBe(true)
		expect(modelled["StarterGui.GetCore"]).toBe(true)
	end)
end)

describe("PlayerMockMethodUtils.readLookup", function()
	it("answers the truthful default for an uninjected lookup", function()
		local player = PlayerMock.new({ UserId = 12345 })

		expect(PlayerMockMethodUtils.readLookup(player, "MarketplaceService.UserOwnsGamePassAsync", 111)).toBe(false)
		expect(PlayerMockMethodUtils.readLookup(player, "GroupService.GetGroupsAsync", 0)).toEqual({})
		expect(PlayerMockMethodUtils.readLookup(player, "Players.GetFriendsAsync", 0)).toEqual({})

		player:Destroy()
	end)

	it("derives the identity lookup's default from the mock itself", function()
		local player = PlayerMock.new({ UserId = 12345 })
		local userInfo = PlayerMockMethodUtils.readLookup(player, "UserService.GetUserInfosByUserIdsAsync", 0)

		expect(userInfo.Id).toBe(12345)
		expect(userInfo.Username).toBe((player :: Instance).Name)

		player:Destroy()
	end)

	it("throws on a domain it does not know", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockMethodUtils.readLookup(player, "NotAService.NotAMethod", 0)
		end).toThrow()

		player:Destroy()
	end)

	it("accepts the path table form of a domain", function()
		local player = PlayerMock.new()

		expect(PlayerMockMethodUtils.readLookup(player, { "MarketplaceService", "UserOwnsGamePassAsync" }, 111)).toBe(
			false
		)

		player:Destroy()
	end)
end)

describe("PlayerMockMethodUtils.writeLookup", function()
	it("round-trips a scalar", function()
		local player = PlayerMock.new()
		PlayerMockMethodUtils.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", true, 111)

		expect(PlayerMockMethodUtils.readLookup(player, "MarketplaceService.UserOwnsGamePassAsync", 111)).toBe(true)
		expect(PlayerMockMethodUtils.readLookup(player, "MarketplaceService.UserOwnsGamePassAsync", 222)).toBe(false)

		player:Destroy()
	end)

	it("round-trips a table by reference", function()
		local player = PlayerMock.new()
		local groupInfo = {
			IsMember = true,
			Roles = { { Name = "Admin", Rank = 230 } },
		}
		PlayerMockMethodUtils.writeLookup(player, "GroupService.GetRolesInGroupAsync", groupInfo, 372)

		expect(PlayerMockMethodUtils.readLookup(player, "GroupService.GetRolesInGroupAsync", 372)).toBe(groupInfo)

		player:Destroy()
	end)

	it("reaches a method the mock models no stand-in for", function()
		local player = PlayerMock.new()
		PlayerMockMethodUtils.writeLookup(player, "Player.RequestStreamAroundAsync", "streamed")

		expect(PlayerMockMethodUtils.call(player, "Player.RequestStreamAroundAsync")).toBe("streamed")

		player:Destroy()
	end)

	it("answers what the domain models again when passed nil", function()
		local player = PlayerMock.new()
		PlayerMockMethodUtils.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", true, 111)
		PlayerMockMethodUtils.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", nil, 111)

		expect(PlayerMockMethodUtils.readLookup(player, "MarketplaceService.UserOwnsGamePassAsync", 111)).toBe(false)

		player:Destroy()
	end)

	it("holds the injected value to the domain's shape when it is read", function()
		local player = PlayerMock.new()
		PlayerMockMethodUtils.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", "yes" :: any, 111)
		PlayerMockMethodUtils.writeLookup(player, "GroupService.GetRolesInGroupAsync", { IsMember = 1 } :: any, 372)

		expect(function()
			PlayerMockMethodUtils.readLookup(player, "MarketplaceService.UserOwnsGamePassAsync", 111)
		end).toThrow()
		expect(function()
			PlayerMockMethodUtils.readLookup(player, "GroupService.GetRolesInGroupAsync", 372)
		end).toThrow()

		player:Destroy()
	end)

	it("throws on arguments of the wrong shape", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockMethodUtils.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", true, "111" :: any)
		end).toThrow()

		player:Destroy()
	end)
end)

describe("PlayerMockMethodUtils lookup arguments", function()
	it("requires an integer for an ID-keyed domain", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockMethodUtils.readLookup(player, "MarketplaceService.UserOwnsGamePassAsync", 1.5)
		end).toThrow()
		expect(function()
			PlayerMockMethodUtils.readLookup(player, "MarketplaceService.UserOwnsGamePassAsync", "111" :: any)
		end).toThrow()

		player:Destroy()
	end)

	it("requires the right enum for an EnumItem-keyed domain", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockMethodUtils.readLookup(player, "StarterGui.SetCoreGuiEnabled", 1)
		end).toThrow()
		expect(function()
			PlayerMockMethodUtils.readLookup(player, "StarterGui.SetCoreGuiEnabled", Enum.KeyCode.E)
		end).toThrow()

		player:Destroy()
	end)

	it("requires a non-empty string for a string-keyed domain", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockMethodUtils.readLookup(player, "MarketplaceService.GetUserSubscriptionStatusAsync", "")
		end).toThrow()
		expect(function()
			PlayerMockMethodUtils.readLookup(player, "MarketplaceService.GetUserSubscriptionStatusAsync", 123)
		end).toThrow()

		player:Destroy()
	end)

	it("keeps same-named values of different enums apart", function()
		local player = PlayerMock.new()

		PlayerMockMethodUtils.writeLookup(player, "UserInputService.IsKeyDown", true, Enum.KeyCode.ButtonA)

		expect(
			PlayerMockMethodUtils.readLookup(
				player,
				"UserInputService.IsMouseButtonPressed",
				Enum.UserInputType.MouseButton1
			)
		).toBe(false)

		player:Destroy()
	end)
end)

describe("PlayerMockMethodUtils.call", function()
	it("performs the replication focus methods", function()
		local player = PlayerMock.new()
		local part = Instance.new("Part")

		PlayerMockMethodUtils.call(player, "Player.AddReplicationFocus", part)
		expect(PlayerMockReplicationFocusUtils.getReplicationFocuses(player)).toEqual({ part })

		PlayerMockMethodUtils.call(player, "Player.RemoveReplicationFocus", part)
		expect(PlayerMockReplicationFocusUtils.getReplicationFocuses(player)).toEqual({})

		part:Destroy()
		player:Destroy()
	end)

	it("answers a lookup domain with its injected result", function()
		local player = PlayerMock.new()

		expect(PlayerMockMethodUtils.call(player, "MarketplaceService.UserOwnsGamePassAsync", 111)).toBe(false)
		PlayerMockMethodUtils.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", true, 111)
		expect(PlayerMockMethodUtils.call(player, "MarketplaceService.UserOwnsGamePassAsync", 111)).toBe(true)

		player:Destroy()
	end)

	it("throws on a path that names no real method", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockMethodUtils.call(player, "Player.NotARealMethod")
		end).toThrow()
		expect(function()
			PlayerMockMethodUtils.call(player, "NotARealClassName.Kick")
		end).toThrow()
		expect(function()
			PlayerMockMethodUtils.call(player, "Kick")
		end).toThrow()

		player:Destroy()
	end)

	it("throws on a real method the mock models no stand-in for", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockMethodUtils.call(player, "Player.RequestStreamAroundAsync")
		end).toThrow()

		player:Destroy()
	end)
end)

describe("PlayerMockMethodUtils.bindMethod", function()
	it("displaces the modelled stand-in for a performed method", function()
		local player = PlayerMock.new()
		local seen

		PlayerMockMethodUtils.bindMethod(player, "Player.Kick", function(_player, message)
			seen = message
			return nil
		end)
		PlayerMockMethodUtils.call(player, "Player.Kick", "Go away")

		expect(seen).toBe("Go away")
		expect(PlayerMockMethodUtils.getKickMessage(player)).toBeNil()

		player:Destroy()
	end)

	it("displaces a lookup, so a stand-in can compute rather than answer a value", function()
		local player = PlayerMock.new()
		local calls = 0

		PlayerMockMethodUtils.bindMethod(player, "MarketplaceService.UserOwnsGamePassAsync", function()
			calls += 1
			return calls > 1
		end)

		expect(PlayerMockMethodUtils.call(player, "MarketplaceService.UserOwnsGamePassAsync", 111)).toBe(false)
		expect(PlayerMockMethodUtils.call(player, "MarketplaceService.UserOwnsGamePassAsync", 111)).toBe(true)

		player:Destroy()
	end)

	it("wins over an answer injected for one argument tuple", function()
		local player = PlayerMock.new()
		PlayerMockMethodUtils.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", true, 111)

		PlayerMockMethodUtils.bindMethod(player, "MarketplaceService.UserOwnsGamePassAsync", function()
			return false
		end)

		expect(PlayerMockMethodUtils.call(player, "MarketplaceService.UserOwnsGamePassAsync", 111)).toBe(false)

		player:Destroy()
	end)

	it("reaches a real method the mock models no stand-in for", function()
		local player = PlayerMock.new()

		PlayerMockMethodUtils.bindMethod(player, "Player.RequestStreamAroundAsync", function()
			return "streamed"
		end)

		expect(PlayerMockMethodUtils.call(player, "Player.RequestStreamAroundAsync")).toBe("streamed")

		player:Destroy()
	end)

	it("hands tables across by reference rather than as copies", function()
		local player = PlayerMock.new()
		local friends = { { Id = 1, Username = "A", DisplayName = "A", IsOnline = true } }

		PlayerMockMethodUtils.bindMethod(player, "Players.GetFriendsAsync", function()
			return friends
		end)

		expect(PlayerMockMethodUtils.call(player, "Players.GetFriendsAsync", 0)).toBe(friends)

		player:Destroy()
	end)

	it("replaces the previous callback rather than stacking", function()
		local player = PlayerMock.new()

		PlayerMockMethodUtils.bindMethod(player, "Player.IsFriendsWithAsync", function()
			return false
		end)
		PlayerMockMethodUtils.bindMethod(player, "Player.IsFriendsWithAsync", function()
			return true
		end)

		expect(PlayerMockMethodUtils.call(player, "Player.IsFriendsWithAsync", 55)).toBe(true)

		player:Destroy()
	end)

	it("removes the binding when the callback is nil", function()
		local player = PlayerMock.new()

		PlayerMockMethodUtils.bindMethod(player, "Player.IsFriendsWithAsync", function()
			return true
		end)
		PlayerMockMethodUtils.bindMethod(player, "Player.IsFriendsWithAsync", nil)

		expect(PlayerMockMethodUtils.isMethodBound(player, "Player.IsFriendsWithAsync")).toBe(false)
		expect(PlayerMockMethodUtils.call(player, "Player.IsFriendsWithAsync", 55)).toBe(false)

		player:Destroy()
	end)

	it("narrows to one argument tuple when the call's arguments are given", function()
		local player = PlayerMock.new()

		PlayerMockMethodUtils.bindMethod(player, "MarketplaceService.UserOwnsGamePassAsync", function()
			return true
		end, 111)

		expect(PlayerMockMethodUtils.call(player, "MarketplaceService.UserOwnsGamePassAsync", 111)).toBe(true)
		expect(PlayerMockMethodUtils.call(player, "MarketplaceService.UserOwnsGamePassAsync", 222)).toBe(false)

		player:Destroy()
	end)

	it("holds the callback's answer to the domain's shape", function()
		local player = PlayerMock.new()

		PlayerMockMethodUtils.bindMethod(player, "Player.IsFriendsWithAsync", function()
			return "yes"
		end)

		expect(function()
			PlayerMockMethodUtils.call(player, "Player.IsFriendsWithAsync", 55)
		end).toThrow()

		player:Destroy()
	end)

	it("is isolated per mock", function()
		local first = PlayerMock.new()
		local second = PlayerMock.new()

		PlayerMockMethodUtils.bindMethod(first, "Player.IsFriendsWithAsync", function()
			return true
		end)

		expect(PlayerMockMethodUtils.isMethodBound(first, "Player.IsFriendsWithAsync")).toBe(true)
		expect(PlayerMockMethodUtils.isMethodBound(second, "Player.IsFriendsWithAsync")).toBe(false)
		expect(PlayerMockMethodUtils.call(second, "Player.IsFriendsWithAsync", 55)).toBe(false)

		first:Destroy()
		second:Destroy()
	end)

	it("hands back a function that removes the binding", function()
		local player = PlayerMock.new()

		local unbind = PlayerMockMethodUtils.bindMethod(player, "Player.IsFriendsWithAsync", function()
			return true
		end)
		expect(PlayerMockMethodUtils.call(player, "Player.IsFriendsWithAsync", 55)).toBe(true)

		unbind()

		expect(PlayerMockMethodUtils.isMethodBound(player, "Player.IsFriendsWithAsync")).toBe(false)
		expect(PlayerMockMethodUtils.call(player, "Player.IsFriendsWithAsync", 55)).toBe(false)

		player:Destroy()
	end)

	it("leaves a later binding alone when an earlier cleanup runs", function()
		local player = PlayerMock.new()

		local unbindFirst = PlayerMockMethodUtils.bindMethod(player, "Player.IsFriendsWithAsync", function()
			return false
		end)
		PlayerMockMethodUtils.bindMethod(player, "Player.IsFriendsWithAsync", function()
			return true
		end)

		unbindFirst()

		expect(PlayerMockMethodUtils.isMethodBound(player, "Player.IsFriendsWithAsync")).toBe(true)
		expect(PlayerMockMethodUtils.call(player, "Player.IsFriendsWithAsync", 55)).toBe(true)

		player:Destroy()
	end)

	it("removes the binding it came from, not the whole method's", function()
		local player = PlayerMock.new()

		PlayerMockMethodUtils.bindMethod(player, "MarketplaceService.UserOwnsGamePassAsync", function()
			return true
		end)
		local unbindTuple = PlayerMockMethodUtils.bindMethod(
			player,
			"MarketplaceService.UserOwnsGamePassAsync",
			function()
				return true
			end,
			111
		)

		unbindTuple()

		expect(PlayerMockMethodUtils.isMethodBound(player, "MarketplaceService.UserOwnsGamePassAsync", 111)).toBe(false)
		expect(PlayerMockMethodUtils.isMethodBound(player, "MarketplaceService.UserOwnsGamePassAsync")).toBe(true)

		player:Destroy()
	end)

	it("is a no-op called twice", function()
		local player = PlayerMock.new()

		local unbind = PlayerMockMethodUtils.bindMethod(player, "Player.IsFriendsWithAsync", function()
			return true
		end)
		unbind()

		expect(function()
			unbind()
		end).never.toThrow()

		player:Destroy()
	end)

	it("throws on a path that names no real method", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockMethodUtils.bindMethod(player, "Player.NotARealMethod", function() end)
		end).toThrow()

		player:Destroy()
	end)
end)

describe("PlayerMockMethodUtils.unbindMethod", function()
	it("restores the modelled stand-in", function()
		local player = PlayerMock.new()

		PlayerMockMethodUtils.bindMethod(player, "Player.IsFriendsWithAsync", function()
			return true
		end)
		PlayerMockMethodUtils.unbindMethod(player, "Player.IsFriendsWithAsync")

		expect(PlayerMockMethodUtils.isMethodBound(player, "Player.IsFriendsWithAsync")).toBe(false)
		expect(PlayerMockMethodUtils.call(player, "Player.IsFriendsWithAsync", 55)).toBe(false)

		player:Destroy()
	end)

	it("removes a binding made over one argument tuple", function()
		local player = PlayerMock.new()

		PlayerMockMethodUtils.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", true, 111)
		PlayerMockMethodUtils.unbindMethod(player, "MarketplaceService.UserOwnsGamePassAsync", 111)

		expect(PlayerMockMethodUtils.call(player, "MarketplaceService.UserOwnsGamePassAsync", 111)).toBe(false)

		player:Destroy()
	end)

	it("is a no-op for a method that was never bound", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockMethodUtils.unbindMethod(player, "Player.IsFriendsWithAsync")
		end).never.toThrow()

		player:Destroy()
	end)
end)
