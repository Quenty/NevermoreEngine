--!strict
--[[
	Unit tests for RxCharacterUtils.lua
]]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Jest = require("Jest")
local Maid = require("Maid")
local Observable = require("Observable")
local RxCharacterUtils = require("RxCharacterUtils")

local afterAll = Jest.Globals.afterAll
local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Test instances (shared across all tests)
local character = Instance.new("Model")
character.Name = "MockCharacter"

local childPart = Instance.new("Part")
childPart.Name = "ChildPart"
childPart.Parent = character

local unrelatedPart = Instance.new("Part")
unrelatedPart.Name = "UnrelatedPart"

-- Save original before any overrides
local originalObserveLocalPlayerCharacter = RxCharacterUtils.observeLocalPlayerCharacter

--[[
	Creates a mock environment that:
	1. Injects a proxy for Players so Players.LocalPlayer is truthy
	2. Overrides observeLocalPlayerCharacter to return a controllable observable
	Returns setCharacter(char) to change the character and cleanup() to restore.
]]
local function createMockEnvironment()
	local currentCharacter: Model? = nil
	local subscribers: { any } = {}

	-- Mock Players: only needs .LocalPlayer to be truthy to pass the nil-check
	-- in observeIsOfLocalCharacter. We never pass this to RxInstanceUtils.
	local mockPlayers = newproxy(true)
	local mt = getmetatable(mockPlayers)
	mt.__index = function(_, key)
		if key == "LocalPlayer" then
			return true
		end

		error("Bad index " .. tostring(key) .. " on mock Players")
	end

	RxCharacterUtils._test_injectPlayerService(mockPlayers :: any)

	-- Override observeLocalPlayerCharacter so it doesn't call
	-- RxInstanceUtils.observeProperty(Players, "LocalPlayer") which requires a real Instance.
	RxCharacterUtils.observeLocalPlayerCharacter = function()
		return Observable.new(function(sub)
			table.insert(subscribers, sub)
			sub:Fire(currentCharacter)
			return function()
				local idx = table.find(subscribers, sub)
				if idx then
					table.remove(subscribers, idx)
				end
			end
		end) :: any
	end

	local function setCharacter(char: Model?)
		currentCharacter = char
		for _, sub in subscribers do
			sub:Fire(char)
		end
	end

	local function cleanup()
		RxCharacterUtils.observeLocalPlayerCharacter = originalObserveLocalPlayerCharacter
		RxCharacterUtils._test_injectPlayerService(nil :: any)
	end

	return setCharacter, cleanup
end

describe("RxCharacterUtils.observeIsOfLocalCharacter", function()
	local maid = Maid.new()
	local setCharacter, cleanupMock = createMockEnvironment()

	-- Subscribe to all three instances at once
	local childPartValue = nil
	local childPartFireCount = 0
	maid:GiveTask(RxCharacterUtils.observeIsOfLocalCharacter(childPart):Subscribe(function(value)
		childPartValue = value
		childPartFireCount += 1
	end))

	local characterValue = nil
	maid:GiveTask(RxCharacterUtils.observeIsOfLocalCharacter(character):Subscribe(function(value)
		characterValue = value
	end))

	local unrelatedValue = nil
	maid:GiveTask(RxCharacterUtils.observeIsOfLocalCharacter(unrelatedPart):Subscribe(function(value)
		unrelatedValue = value
	end))

	afterAll(function()
		maid:Destroy()
		cleanupMock()
	end)

	it("should initially emit false for all instances when no character is set", function()
		expect(childPartValue).toEqual(false)
		expect(characterValue).toEqual(false)
		expect(unrelatedValue).toEqual(false)
	end)

	it("should emit true for descendant and character itself when character is set", function()
		setCharacter(character)
		expect(childPartValue).toEqual(true)
		expect(characterValue).toEqual(true)
	end)

	it("should still emit false for unrelated instance when character is set", function()
		expect(unrelatedValue).toEqual(false)
	end)

	it("should emit false when character is cleared", function()
		setCharacter(nil)
		expect(childPartValue).toEqual(false)
		expect(characterValue).toEqual(false)
	end)

	it("should emit true again when character is restored", function()
		setCharacter(character)
		expect(childPartValue).toEqual(true)
		expect(characterValue).toEqual(true)
		expect(unrelatedValue).toEqual(false)
	end)
end)

describe("RxCharacterUtils.observeIsOfLocalCharacterBrio", function()
	local maid = Maid.new()
	local setCharacter, cleanupMock = createMockEnvironment()

	-- childPart subscription (descendant of character)
	local childPartBrios = {}
	local childPartBrioCount = 0
	maid:GiveTask(RxCharacterUtils.observeIsOfLocalCharacterBrio(childPart):Subscribe(function(brio)
		table.insert(childPartBrios, brio)
		childPartBrioCount += 1
	end))

	-- unrelatedPart subscription
	local unrelatedBrioCount = 0
	maid:GiveTask(RxCharacterUtils.observeIsOfLocalCharacterBrio(unrelatedPart):Subscribe(function(_brio)
		unrelatedBrioCount += 1
	end))

	-- Separate subscription to test that destroying a sub kills its brio
	local cleanupTestBrio = nil
	local cleanupSub = RxCharacterUtils.observeIsOfLocalCharacterBrio(childPart):Subscribe(function(brio)
		cleanupTestBrio = brio
	end)

	afterAll(function()
		maid:Destroy()
		cleanupSub:Destroy()
		cleanupMock()
	end)

	it("should not emit any brio initially when character is nil", function()
		expect(childPartBrioCount).toEqual(0)
		expect(unrelatedBrioCount).toEqual(0)
	end)

	it("should emit a living brio for descendant when character is set", function()
		setCharacter(character)
		expect(childPartBrioCount).toEqual(1)
		expect(Brio.isBrio(childPartBrios[1])).toEqual(true)
		expect(childPartBrios[1]:IsDead()).toEqual(false)
		expect(childPartBrios[1]:GetValue()).toEqual(true)
	end)

	it("should not emit a brio for unrelated instance when character is set", function()
		expect(unrelatedBrioCount).toEqual(0)
	end)

	it("should kill the brio when character is cleared", function()
		local firstBrio = childPartBrios[1]
		setCharacter(nil)
		expect(firstBrio:IsDead()).toEqual(true)
	end)

	it("should emit a new living brio when character is restored", function()
		setCharacter(character)
		expect(childPartBrioCount).toEqual(2)

		local secondBrio = childPartBrios[2]
		expect(Brio.isBrio(secondBrio)).toEqual(true)
		expect(secondBrio:IsDead()).toEqual(false)
		expect(secondBrio:GetValue()).toEqual(true)
		-- Should be a different brio than the first one
		expect(secondBrio).never.toBe(childPartBrios[1])
	end)

	it("should kill the brio when subscription is destroyed", function()
		expect(cleanupTestBrio).never.toBeNil()
		expect(cleanupTestBrio:IsDead()).toEqual(false)
		local brioRef = cleanupTestBrio
		cleanupSub:Destroy()
		expect(brioRef:IsDead()).toEqual(true)
	end)
end)
