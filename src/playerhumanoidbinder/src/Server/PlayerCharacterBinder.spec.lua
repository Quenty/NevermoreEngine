--!strict
--[[
	Coverage for PlayerCharacterBinder, which auto-tags every player's character. Real players never
	join a headless Open Cloud place, so the tests drive PlayerMocks from the bag's PlayerMockService:
	the binder discovers each mock like a real join and connects the mock's stand-in CharacterAdded
	(see PlayerMock), so PlayerMock.loadCharacterAsync flows through discovery -> Tag -> bind with no
	test reaching in to Tag/Bind by hand. A bare Character write deliberately does not fire
	CharacterAdded -- mirroring the engine, where it only fires during avatar loading.

	@class PlayerCharacterBinder.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local Jest = require("Jest")
local PlayerCharacterBinder = require("PlayerCharacterBinder")
local PlayerHumanoidBinderTestUtils = require("PlayerHumanoidBinderTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local makeTrackingClass = PlayerHumanoidBinderTestUtils.makeTrackingClass
local awaitUnbound = PlayerHumanoidBinderTestUtils.awaitUnbound

local function setup(constructor: any?)
	return PlayerHumanoidBinderTestUtils.setup(PlayerCharacterBinder, "PlayerCharacterBinder", constructor)
end

describe("PlayerCharacterBinder.new()", function()
	it("is a Binder that reports its class name and tag", function()
		-- Never Init'd/Started, so it holds no resources and needs no teardown.
		local binder = PlayerCharacterBinder.new("PlayerCharacterBinderMetaSpecTag", makeTrackingClass())
		expect(Binder.isBinder(binder)).toEqual(true)
		expect((binder :: any).ClassName).toEqual("PlayerCharacterBinder")
		expect(binder:GetTag()).toEqual("PlayerCharacterBinderMetaSpecTag")
	end)
end)

describe("PlayerCharacterBinder automatic tagging API", function()
	it("defaults to enabled and observes changes", function()
		local controller = setup()
		controller.boot()

		local emissions = {}
		local sub = controller.binder:ObserveAutomaticTagging():Subscribe(function(value: boolean)
			table.insert(emissions, value)
		end)

		expect(emissions[1]).toEqual(true)

		controller.binder:SetAutomaticTagging(false)
		expect(emissions[2]).toEqual(false)

		sub:Destroy()
		controller.destroy()
	end)

	it("throws on a non-boolean", function()
		local controller = setup()
		controller.boot()

		expect(function()
			controller.binder:SetAutomaticTagging(nil :: any)
		end).toThrow()

		controller.destroy()
	end)

	it("ObserveAutomaticTaggingBrio kills the brio when the value changes", function()
		local controller = setup()
		controller.boot()

		local brios: { any } = {}
		local sub = controller.binder:ObserveAutomaticTaggingBrio():Subscribe(function(brio: any)
			table.insert(brios, brio)
		end)

		expect(#brios).toEqual(1)
		expect(brios[1]:IsDead()).toEqual(false)

		controller.binder:SetAutomaticTagging(false)

		expect(brios[1]:IsDead()).toEqual(true)
		expect(#brios).toEqual(2)
		expect(brios[2]:GetValue()).toEqual(false)

		sub:Destroy()
		controller.destroy()
	end)
end)

describe("PlayerCharacterBinder character discovery", function()
	it("binds the current character of a mock that exists before start", function()
		local controller = setup()
		controller.init()

		local mock = controller.newMock(1)
		local character = controller.newCharacter()
		controller.setCharacter(mock, character)

		controller.start()

		local ok, class = controller.binder:Promise(character):Yield()
		assert(ok, "Never bound")
		expect(class.instance).toEqual(character)
		expect(controller.binder:HasTag(character)).toEqual(true)

		controller.destroy()
	end)

	it("binds a character spawned after start", function()
		local controller = setup()
		controller.boot()

		local mock = controller.newMock(2)
		local character = controller.newCharacter()
		controller.loadCharacter(mock, character)

		local ok, class = controller.binder:Promise(character):Yield()
		assert(ok, "Never bound")
		expect(class.instance).toEqual(character)

		controller.destroy()
	end)

	it("does not bind a bare Character write", function()
		-- CharacterAdded only fires during avatar loading; a bare .Character assignment does not fire
		-- it, and PlayerMock.write mirrors that -- so the binder deliberately does not see the model.
		local controller = setup()
		controller.boot()

		local mock = controller.newMock()
		local character = controller.newCharacter()
		controller.setCharacter(mock, character)

		task.wait(0.1)
		expect(controller.binder:Get(character)).toBeNil()

		controller.destroy()
	end)

	it("spawning a replacement despawns and unbinds the old character", function()
		local controller = setup()
		controller.boot()

		local mock = controller.newMock()
		local first = controller.newCharacter()
		controller.loadCharacter(mock, first)
		local okFirst, firstClass = controller.binder:Promise(first):Yield()
		assert(okFirst, "First never bound")

		local second = controller.newCharacter()
		controller.loadCharacter(mock, second)
		local ok, class = controller.binder:Promise(second):Yield()
		assert(ok, "Second never bound")

		-- LoadCharacter semantics: the old character is destroyed, so its binding tears down.
		awaitUnbound(controller.binder, first)
		expect(controller.binder:Get(first)).toBeNil()
		expect(firstClass.destroyed).toEqual(true)
		expect(controller.binder:Get(second)).toEqual(class)

		controller.destroy()
	end)

	it("unbinds and destroys the class when the character is destroyed", function()
		local controller = setup()
		controller.boot()

		local mock = controller.newMock()
		local character = controller.newCharacter()
		controller.loadCharacter(mock, character)

		local ok, class = controller.binder:Promise(character):Yield()
		assert(ok, "Never bound")

		character:Destroy()
		awaitUnbound(controller.binder, character)

		expect(controller.binder:Get(character)).toBeNil()
		expect(class.destroyed).toEqual(true)

		controller.destroy()
	end)

	it("despawns and unbinds the character when the mock is destroyed", function()
		-- Mirrors the engine: a leaving player's character is removed, so a destroyed mock takes its
		-- character (and therefore the binding) with it.
		local controller = setup()
		controller.boot()

		local mock = controller.newMock()
		local character = controller.newCharacter()
		controller.loadCharacter(mock, character)

		local ok, class = controller.binder:Promise(character):Yield()
		assert(ok, "Never bound")

		mock:Destroy()
		awaitUnbound(controller.binder, character)

		expect(controller.binder:Get(character)).toBeNil()
		expect(class.destroyed).toEqual(true)

		controller.destroy()
	end)
end)

describe("PlayerCharacterBinder:SetAutomaticTagging(false)", function()
	it("unbinds existing mock characters", function()
		local controller = setup()
		controller.boot()

		local mock = controller.newMock()
		local character = controller.newCharacter()
		controller.loadCharacter(mock, character)

		local ok, class = controller.binder:Promise(character):Yield()
		assert(ok, "Never bound")

		controller.binder:SetAutomaticTagging(false)
		awaitUnbound(controller.binder, character)

		expect(controller.binder:Get(character)).toBeNil()
		expect(class.destroyed).toEqual(true)

		controller.destroy()
	end)

	it("stops discovering while disabled and rediscovers on re-enable", function()
		local controller = setup()
		controller.boot()

		controller.binder:SetAutomaticTagging(false)

		local mock = controller.newMock()
		local character = controller.newCharacter()
		controller.loadCharacter(mock, character)

		task.wait(0.1)
		expect(controller.binder:Get(character)).toBeNil()

		controller.binder:SetAutomaticTagging(true)

		local ok = controller.binder:Promise(character):Yield()
		expect(ok).toEqual(true)

		controller.destroy()
	end)
end)

describe("PlayerCharacterBinder teardown", function()
	it("destroys bound classes when the service bag is destroyed", function()
		local controller = setup()
		controller.boot()

		local mock = controller.newMock()
		local character = controller.newCharacter()
		controller.loadCharacter(mock, character)

		local ok, class = controller.binder:Promise(character):Yield()
		assert(ok, "Never bound")

		controller.destroy()

		expect(class.destroyed).toEqual(true)
	end)
end)
