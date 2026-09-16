--!strict
--[[
	@class PlayerMockReflectionUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PlayerMockReflectionUtils = require("PlayerMockReflectionUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PlayerMockReflectionUtils.getEventNames", function()
	it("reports the events a class declares itself", function()
		local names = PlayerMockReflectionUtils.getEventNames("Player")
		expect(names).never.toBeNil()
		expect((names :: any).Chatted).toBe(true)
	end)

	it("reports the events a class inherits", function()
		local names = PlayerMockReflectionUtils.getEventNames("Folder")
		expect(names).never.toBeNil()
		expect((names :: any).Destroying).toBe(true)
		expect((names :: any).AncestryChanged).toBe(true)
	end)

	it("omits members that are not events", function()
		local names = PlayerMockReflectionUtils.getEventNames("Folder")
		expect((names :: any).Name).toBeNil()
		expect((names :: any).Parent).toBeNil()
	end)

	it("returns nil for a class that does not exist", function()
		expect(PlayerMockReflectionUtils.getEventNames("NotARealClassName")).toBeNil()
	end)

	it("returns nil for an empty class name", function()
		expect(PlayerMockReflectionUtils.getEventNames("")).toBeNil()
	end)

	it("caches the set it built", function()
		expect(PlayerMockReflectionUtils.getEventNames("Folder")).toBe(
			PlayerMockReflectionUtils.getEventNames("Folder")
		)
	end)
end)

describe("PlayerMockReflectionUtils.isClassEvent", function()
	it("is true for an event the class declares", function()
		expect(PlayerMockReflectionUtils.isClassEvent("Player", "Chatted")).toBe(true)
	end)

	it("is true for an event the class inherits", function()
		expect(PlayerMockReflectionUtils.isClassEvent("Player", "Destroying")).toBe(true)
	end)

	it("is false for an event belonging to another class", function()
		expect(PlayerMockReflectionUtils.isClassEvent("Folder", "Chatted")).toBe(false)
	end)

	it("is false for a member that is not an event", function()
		expect(PlayerMockReflectionUtils.isClassEvent("Player", "Name")).toBe(false)
	end)

	it("is false for a name no class member has", function()
		expect(PlayerMockReflectionUtils.isClassEvent("Player", "NotARealEventName")).toBe(false)
	end)

	it("is false rather than an error for a class that does not exist", function()
		expect(PlayerMockReflectionUtils.isClassEvent("NotARealClassName", "Destroying")).toBe(false)
	end)
end)

describe("PlayerMockReflectionUtils.getPropertyNames", function()
	it("reports the properties a class declares itself", function()
		local names = PlayerMockReflectionUtils.getPropertyNames("Player")
		expect(names).never.toBeNil()
		expect((names :: any).UserId).toBe(true)
		expect((names :: any).DisplayName).toBe(true)
	end)

	it("reports the properties a class inherits", function()
		local names = PlayerMockReflectionUtils.getPropertyNames("Player")
		expect((names :: any).Name).toBe(true)
		expect((names :: any).Parent).toBe(true)
	end)

	it("omits methods, which are not properties", function()
		local names = PlayerMockReflectionUtils.getPropertyNames("Player")
		expect((names :: any).HasAppearanceLoaded).toBeNil()
	end)

	it("returns nil for a class that does not exist", function()
		expect(PlayerMockReflectionUtils.getPropertyNames("NotARealClassName")).toBeNil()
	end)

	it("caches the set it built", function()
		expect(PlayerMockReflectionUtils.getPropertyNames("Player")).toBe(
			PlayerMockReflectionUtils.getPropertyNames("Player")
		)
	end)
end)

describe("PlayerMockReflectionUtils.isClass", function()
	it("is true for a service", function()
		expect(PlayerMockReflectionUtils.isClass("GuiService")).toBe(true)
	end)

	it("is true for a class nothing can construct", function()
		expect(PlayerMockReflectionUtils.isClass("Player")).toBe(true)
	end)

	it("is true for an abstract base class", function()
		expect(PlayerMockReflectionUtils.isClass("Instance")).toBe(true)
	end)

	it("is false for a name no class carries", function()
		expect(PlayerMockReflectionUtils.isClass("NotARealClassName")).toBe(false)
	end)
end)

describe("PlayerMockReflectionUtils.isService", function()
	it("is true for a service", function()
		expect(PlayerMockReflectionUtils.isService("GuiService")).toBe(true)
		expect(PlayerMockReflectionUtils.isService("UserInputService")).toBe(true)
	end)

	-- A headless server instantiates almost none of these, and whether a batch run has reached for
	-- one first must not change the answer.
	it("is true for a service the DataModel has no instance of", function()
		expect(PlayerMockReflectionUtils.isService("GroupService")).toBe(true)
		expect(PlayerMockReflectionUtils.isService("UserService")).toBe(true)
		expect(PlayerMockReflectionUtils.isService("TeleportService")).toBe(true)
	end)

	it("is false for an instance class anything can hold", function()
		expect(PlayerMockReflectionUtils.isService("Folder")).toBe(false)
		expect(PlayerMockReflectionUtils.isService("Player")).toBe(false)
	end)

	it("is false rather than an error for a name no class carries", function()
		expect(PlayerMockReflectionUtils.isService("NotARealClassName")).toBe(false)
		expect(PlayerMockReflectionUtils.isService("")).toBe(false)
	end)
end)

describe("PlayerMockReflectionUtils.isClassMethod", function()
	it("is true for a method the class declares", function()
		expect(PlayerMockReflectionUtils.isClassMethod("Player", "IsFriendsWithAsync")).toBe(true)
	end)

	it("is true for a method the class inherits", function()
		expect(PlayerMockReflectionUtils.isClassMethod("Player", "FindFirstChild")).toBe(true)
	end)

	it("is false for a member that is not a method", function()
		expect(PlayerMockReflectionUtils.isClassMethod("Player", "UserId")).toBe(false)
		expect(PlayerMockReflectionUtils.isClassMethod("Player", "Chatted")).toBe(false)
	end)

	it("is false rather than an error for a class that does not exist", function()
		expect(PlayerMockReflectionUtils.isClassMethod("NotARealClassName", "FindFirstChild")).toBe(false)
	end)
end)

describe("PlayerMockReflectionUtils.isClassProperty", function()
	it("is true for a property the class declares", function()
		expect(PlayerMockReflectionUtils.isClassProperty("Player", "UserId")).toBe(true)
	end)

	it("is true for a property the class inherits", function()
		expect(PlayerMockReflectionUtils.isClassProperty("Player", "Name")).toBe(true)
	end)

	it("is false for a property belonging to another class", function()
		expect(PlayerMockReflectionUtils.isClassProperty("Folder", "UserId")).toBe(false)
	end)

	it("is false for a member that is not a property", function()
		expect(PlayerMockReflectionUtils.isClassProperty("Player", "Chatted")).toBe(false)
	end)

	it("is false rather than an error for a class that does not exist", function()
		expect(PlayerMockReflectionUtils.isClassProperty("NotARealClassName", "Name")).toBe(false)
	end)
end)

describe("PlayerMockReflectionUtils.findNativeSignal", function()
	it("returns the genuine signal for an inherited event", function()
		local folder = Instance.new("Folder")

		local signal = PlayerMockReflectionUtils.findNativeSignal(folder, "Destroying")
		expect(typeof(signal)).toBe("RBXScriptSignal")

		folder:Destroy()
	end)

	it("returns a signal that connects like any other", function()
		local folder = Instance.new("Folder")

		local signal = PlayerMockReflectionUtils.findNativeSignal(folder, "ChildAdded")
		local connection = (signal :: RBXScriptSignal):Connect(function() end)
		expect(connection.Connected).toBe(true)

		connection:Disconnect()
		folder:Destroy()
	end)

	it("returns nil for an event the instance's class does not have", function()
		local folder = Instance.new("Folder")

		expect(PlayerMockReflectionUtils.findNativeSignal(folder, "Chatted")).toBeNil()

		folder:Destroy()
	end)

	it("returns nil for a member that is not an event", function()
		local folder = Instance.new("Folder")

		expect(PlayerMockReflectionUtils.findNativeSignal(folder, "Name")).toBeNil()

		folder:Destroy()
	end)

	it("returns nil for a name no member has", function()
		local folder = Instance.new("Folder")

		expect(PlayerMockReflectionUtils.findNativeSignal(folder, "NotARealEventName")).toBeNil()

		folder:Destroy()
	end)
end)
