--!strict
--[[
	@class PlayerMockInputUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MockInputObject = require("MockInputObject")
local PlayerMock = require("PlayerMock")
local PlayerMockInputUtils = require("PlayerMockInputUtils")
local PlayerMockMethodUtils = require("PlayerMockMethodUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PlayerMockInputUtils.isInputBound", function()
	it("is false before anything is bound", function()
		local player = PlayerMock.new()

		expect(PlayerMockInputUtils.isInputBound(player, "Drag")).toBe(false)

		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")

		expect(function()
			PlayerMockInputUtils.isInputBound(folder :: any, "Drag")
		end).toThrow()

		folder:Destroy()
	end)
end)

describe("PlayerMockMethodUtils.call ContextActionService binds", function()
	it("binds an action fireInput then dispatches", function()
		local player = PlayerMock.new()
		PlayerMockMethodUtils.call(player, "ContextActionService.BindAction", "Drag", function() end, false)

		expect(PlayerMockInputUtils.isInputBound(player, "Drag")).toBe(true)

		player:Destroy()
	end)

	it("unbinds through the same entry point", function()
		local player = PlayerMock.new()
		PlayerMockMethodUtils.call(player, "ContextActionService.BindAction", "Drag", function() end, false)
		PlayerMockMethodUtils.call(player, "ContextActionService.UnbindAction", "Drag")

		expect(PlayerMockInputUtils.isInputBound(player, "Drag")).toBe(false)

		player:Destroy()
	end)

	it("is a no-op unbinding an action that was never bound", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockMethodUtils.call(player, "ContextActionService.UnbindAction", "Drag")
		end).never.toThrow()

		player:Destroy()
	end)

	it("shares one registry across bind domains, so rebinding a name replaces the callback", function()
		local player = PlayerMock.new()
		local calls = {}

		PlayerMockMethodUtils.call(player, "ContextActionService.BindAction", "Drag", function()
			table.insert(calls, "first")
			return nil
		end, false)
		PlayerMockMethodUtils.call(player, "ContextActionService.BindActionAtPriority", "Drag", function()
			table.insert(calls, "second")
			return nil
		end, false, 2000)

		PlayerMockInputUtils.fireInput(player, "Drag", Enum.UserInputState.Begin)

		expect(calls).toEqual({ "second" })

		player:Destroy()
	end)

	it("throws on a domain it does not know", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockMethodUtils.call(player, "ContextActionService.NotAMethod", "Drag", function() end, false)
		end).toThrow()

		player:Destroy()
	end)

	it("throws when BindActionAtPriority is given no priority", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockMethodUtils.call(
				player,
				"ContextActionService.BindActionAtPriority",
				"Drag",
				function() end,
				false
			)
		end).toThrow()

		player:Destroy()
	end)
end)

describe("PlayerMockInputUtils.fireInput", function()
	it("dispatches with the engine's argument order and returns the callback's result", function()
		local player = PlayerMock.new()
		local seenActionName, seenInputState

		PlayerMockMethodUtils.call(
			player,
			"ContextActionService.BindAction",
			"Drag",
			function(actionName, userInputState)
				seenActionName = actionName
				seenInputState = userInputState
				return Enum.ContextActionResult.Pass
			end,
			false
		)

		local result = PlayerMockInputUtils.fireInput(player, "Drag", Enum.UserInputState.Begin)

		expect(seenActionName).toBe("Drag")
		expect(seenInputState).toBe(Enum.UserInputState.Begin)
		expect(result).toBe(Enum.ContextActionResult.Pass)

		player:Destroy()
	end)

	it("hands a MockInputObject across by reference, keeping its methods", function()
		local player = PlayerMock.new()
		local inputObject = MockInputObject.new({ KeyCode = Enum.KeyCode.E })
		local seenKeyCode, seenIsSame

		PlayerMockMethodUtils.call(
			player,
			"ContextActionService.BindAction",
			"Drag",
			function(_actionName, _userInputState, received: any)
				seenKeyCode = received.KeyCode
				seenIsSame = received == inputObject
				return nil
			end,
			false
		)

		PlayerMockInputUtils.fireInput(player, "Drag", Enum.UserInputState.Begin, inputObject)

		expect(seenKeyCode).toBe(Enum.KeyCode.E)
		expect(seenIsSame).toBe(true)

		player:Destroy()
	end)

	it("throws on an action that is not bound", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockInputUtils.fireInput(player, "Drag", Enum.UserInputState.Begin)
		end).toThrow()

		player:Destroy()
	end)

	it("throws on a state from the wrong enum", function()
		local player = PlayerMock.new()
		PlayerMockMethodUtils.call(player, "ContextActionService.BindAction", "Drag", function() end, false)

		expect(function()
			PlayerMockInputUtils.fireInput(player, "Drag", Enum.KeyCode.E :: any)
		end).toThrow()

		player:Destroy()
	end)
end)
