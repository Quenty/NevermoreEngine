--!strict
--[[
	Coverage for PlayerHumanoidBinder, which auto-binds every player's humanoid. Real players never
	join a headless Open Cloud place, so the tests drive PlayerMocks from the bag's PlayerMockService:
	the binder discovers each mock like a real join and the (mock-aware) HumanoidTracker follows the
	mock's stand-in Character property to its real Humanoid child -- so `setCharacter` flows through
	discovery -> tracker -> Bind with no test reaching in to Tag/Bind by hand.

	@class PlayerHumanoidBinder.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderTestUtils = require("BinderTestUtils")
local Jest = require("Jest")
local ObservableSpy = require("ObservableSpy")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")
local PlayerHumanoidBinderTestUtils = require("PlayerHumanoidBinderTestUtils")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(constructor: any?)
	return PlayerHumanoidBinderTestUtils.setup(PlayerHumanoidBinder, "PlayerHumanoidBinder", constructor)
end

describe("PlayerHumanoidBinder.new()", function()
	it("is a Binder that reports its class name and tag", function()
		local binder = PlayerHumanoidBinder.new("PlayerHumanoidBinderMetaSpecTag", BinderTestUtils.makeTrackingClass())
		expect(Binder.isBinder(binder)).toEqual(true)
		expect((binder :: any).ClassName).toEqual("PlayerHumanoidBinder")
		expect(binder:GetTag()).toEqual("PlayerHumanoidBinderMetaSpecTag")
	end)

	it("Init throws without a serviceBag", function()
		local binder = PlayerHumanoidBinder.new("PlayerHumanoidBinderInitSpecTag", BinderTestUtils.makeTrackingClass())
		expect(function()
			(binder :: any):Init()
		end).toThrow()
	end)
end)

describe("PlayerHumanoidBinder automatic tagging API", function()
	it("defaults to enabled and observes changes", function()
		local controller = setup()
		controller.initServiceBag()

		local emissions = ObservableSpy.new(controller.binder:ObserveAutomaticTagging())

		expect(emissions[1]).toEqual(true)

		controller.binder:SetAutomaticTagging(false)
		expect(emissions[2]).toEqual(false)

		emissions:Destroy()
		controller:Destroy()
	end)

	it("throws on a non-boolean", function()
		local controller = setup()
		controller.initServiceBag()

		expect(function()
			controller.binder:SetAutomaticTagging(nil :: any)
		end).toThrow()

		controller:Destroy()
	end)

	it("ObserveAutomaticTaggingBrio kills the brio when the value changes", function()
		local controller = setup()
		controller.initServiceBag()

		local brios = ObservableSpy.new(controller.binder:ObserveAutomaticTaggingBrio())

		expect(#brios).toEqual(1)
		expect(brios[1]:IsDead()).toEqual(false)

		controller.binder:SetAutomaticTagging(false)

		expect(brios[1]:IsDead()).toEqual(true)
		expect(#brios).toEqual(2)
		expect(brios[2]:GetValue()).toEqual(false)

		brios:Destroy()
		controller:Destroy()
	end)
end)

describe("PlayerHumanoidBinder humanoid discovery", function()
	it("binds the humanoid of a mock whose character exists before start", function()
		local controller = setup()
		controller.init()

		local mock = controller.newMock(1)
		local character, humanoid = controller.newCharacter()
		controller.setCharacter(mock, character)

		controller.start()

		local class = PromiseTestUtils.awaitFulfilled(controller.binder:Promise(humanoid))
		expect(class.instance).toEqual(humanoid)
		expect(controller.binder:HasTag(humanoid)).toEqual(true)

		controller:Destroy()
	end)

	it("binds the humanoid when a character is assigned after start", function()
		local controller = setup()
		controller.initServiceBag()

		local mock = controller.newMock(2)
		local character, humanoid = controller.newCharacter()
		controller.setCharacter(mock, character)

		local class = PromiseTestUtils.awaitFulfilled(controller.binder:Promise(humanoid))
		expect(class.instance).toEqual(humanoid)

		controller:Destroy()
	end)

	it("binds a humanoid added to the character later", function()
		local controller = setup()
		controller.initServiceBag()

		local mock = controller.newMock()
		local character = controller.newCharacter(false)
		controller.setCharacter(mock, character)

		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character

		local class = PromiseTestUtils.awaitFulfilled(controller.binder:Promise(humanoid))
		expect(class.instance).toEqual(humanoid)

		controller:Destroy()
	end)

	it("unbinds and destroys the class when the character is destroyed", function()
		local controller = setup()
		controller.initServiceBag()

		local mock = controller.newMock()
		local character, humanoid = controller.newCharacter()
		controller.setCharacter(mock, character)

		local class = PromiseTestUtils.awaitFulfilled(controller.binder:Promise(humanoid))

		character:Destroy()
		expect(controller.binder:Get(humanoid)).toBeNil()

		expect(controller.binder:Get(humanoid)).toBeNil()
		expect(class.destroyed).toEqual(true)

		controller:Destroy()
	end)
end)

describe("PlayerHumanoidBinder:SetAutomaticTagging(false)", function()
	it("unbinds existing mock humanoids and rediscovers on re-enable", function()
		local controller = setup()
		controller.initServiceBag()

		local mock = controller.newMock()
		local character, humanoid = controller.newCharacter()
		controller.setCharacter(mock, character)

		local class = PromiseTestUtils.awaitFulfilled(controller.binder:Promise(humanoid))

		controller.binder:SetAutomaticTagging(false)
		expect(controller.binder:Get(humanoid)).toBeNil()

		expect(controller.binder:Get(humanoid)).toBeNil()
		expect(class.destroyed).toEqual(true)

		controller.binder:SetAutomaticTagging(true)

		PromiseTestUtils.awaitFulfilled(controller.binder:Promise(humanoid))

		controller:Destroy()
	end)

	it("stops discovering while disabled", function()
		local controller = setup()
		controller.initServiceBag()

		controller.binder:SetAutomaticTagging(false)

		local mock = controller.newMock()
		local character, humanoid = controller.newCharacter()
		controller.setCharacter(mock, character)

		expect(controller.binder:Get(humanoid)).toBeNil()

		controller:Destroy()
	end)
end)

describe("PlayerHumanoidBinder teardown", function()
	it("destroys bound classes when the service bag is destroyed", function()
		local controller = setup()
		controller.initServiceBag()

		local mock = controller.newMock()
		local character, humanoid = controller.newCharacter()
		controller.setCharacter(mock, character)

		local class = PromiseTestUtils.awaitFulfilled(controller.binder:Promise(humanoid))

		controller:Destroy()

		expect(class.destroyed).toEqual(true)
	end)
end)
