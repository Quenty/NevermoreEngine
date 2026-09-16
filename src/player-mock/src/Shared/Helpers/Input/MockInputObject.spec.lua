--!strict
--[[
	@class MockInputObject.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MockInputObject = require("MockInputObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("MockInputObject.new", function()
	it("defaults every field a real InputObject would carry", function()
		local inputObject = MockInputObject.new()

		expect(inputObject.UserInputType).toBe(Enum.UserInputType.Keyboard)
		expect(inputObject.KeyCode).toBe(Enum.KeyCode.None)
		expect(inputObject.UserInputState).toBe(Enum.UserInputState.Begin)
		expect(inputObject.Position).toBe(Vector3.zero)
		expect(inputObject.Delta).toBe(Vector3.zero)
	end)

	it("takes the fields it is given", function()
		local inputObject = MockInputObject.new({
			UserInputType = Enum.UserInputType.MouseButton2,
			KeyCode = Enum.KeyCode.E,
			UserInputState = Enum.UserInputState.End,
			Position = Vector3.new(1, 2, 3),
			Delta = Vector3.new(4, 5, 6),
		})

		expect(inputObject.UserInputType).toBe(Enum.UserInputType.MouseButton2)
		expect(inputObject.KeyCode).toBe(Enum.KeyCode.E)
		expect(inputObject.UserInputState).toBe(Enum.UserInputState.End)
		expect(inputObject.Position).toBe(Vector3.new(1, 2, 3))
		expect(inputObject.Delta).toBe(Vector3.new(4, 5, 6))
	end)

	it("throws on a UserInputType from the wrong enum", function()
		expect(function()
			MockInputObject.new({ UserInputType = Enum.KeyCode.E :: any })
		end).toThrow()
	end)
end)

describe("MockInputObject.GetPropertyChangedSignal", function()
	it("returns the same signal every time, like the engine's", function()
		local inputObject = MockInputObject.new()

		expect(inputObject:GetPropertyChangedSignal("UserInputState")).toBe(
			inputObject:GetPropertyChangedSignal("UserInputState")
		)
	end)

	it("returns a different signal per property", function()
		local inputObject = MockInputObject.new()

		expect(inputObject:GetPropertyChangedSignal("UserInputState")).never.toBe(
			inputObject:GetPropertyChangedSignal("Position")
		)
	end)

	it("throws on a non-string property name", function()
		local inputObject = MockInputObject.new()

		expect(function()
			inputObject:GetPropertyChangedSignal(5 :: any)
		end).toThrow()
	end)
end)

describe("MockInputObject.SetUserInputState", function()
	it("sets the state and fires its changed signal", function()
		local inputObject = MockInputObject.new()
		local seen = {}

		local connection = inputObject:GetPropertyChangedSignal("UserInputState"):Connect(function()
			table.insert(seen, inputObject.UserInputState)
		end)

		inputObject:SetUserInputState(Enum.UserInputState.End)

		expect(inputObject.UserInputState).toBe(Enum.UserInputState.End)
		expect(seen).toEqual({ Enum.UserInputState.End })

		connection:Disconnect()
	end)

	it("does not fire another property's signal", function()
		local inputObject = MockInputObject.new()
		local fired = 0

		local connection = inputObject:GetPropertyChangedSignal("Position"):Connect(function()
			fired += 1
		end)

		inputObject:SetUserInputState(Enum.UserInputState.End)

		expect(fired).toBe(0)

		connection:Disconnect()
	end)

	it("throws on a state from the wrong enum", function()
		local inputObject = MockInputObject.new()

		expect(function()
			inputObject:SetUserInputState(Enum.KeyCode.E :: any)
		end).toThrow()
	end)
end)
