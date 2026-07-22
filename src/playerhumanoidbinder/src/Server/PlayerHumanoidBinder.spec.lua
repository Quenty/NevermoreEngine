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
local Jest = require("Jest")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")
local PlayerHumanoidBinderTestUtils = require("PlayerHumanoidBinderTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local makeTrackingClass = PlayerHumanoidBinderTestUtils.makeTrackingClass
local awaitUnbound = PlayerHumanoidBinderTestUtils.awaitUnbound

local function setup(constructor: any?)
	return PlayerHumanoidBinderTestUtils.setup(PlayerHumanoidBinder, "PlayerHumanoidBinder", constructor)
end

describe("PlayerHumanoidBinder.new()", function()
	it("is a Binder that reports its class name and tag", function()
		-- Never Init'd/Started, so it holds no resources and needs no teardown.
		local binder = PlayerHumanoidBinder.new("PlayerHumanoidBinderMetaSpecTag", makeTrackingClass())
		expect(Binder.isBinder(binder)).toEqual(true)
		expect((binder :: any).ClassName).toEqual("PlayerHumanoidBinder")
		expect(binder:GetTag()).toEqual("PlayerHumanoidBinderMetaSpecTag")
	end)

	it("Init throws without a serviceBag", function()
		local binder = PlayerHumanoidBinder.new("PlayerHumanoidBinderInitSpecTag", makeTrackingClass())
		expect(function()
			(binder :: any):Init()
		end).toThrow()
	end)
end)

describe("PlayerHumanoidBinder automatic tagging API", function()
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

describe("PlayerHumanoidBinder humanoid discovery", function()
	it("binds the humanoid of a mock whose character exists before start", function()
		local controller = setup()
		controller.init()

		local mock = controller.newMock(1)
		local character, humanoid = controller.newCharacter()
		controller.setCharacter(mock, character)

		controller.start()

		local ok, class = controller.binder:Promise(humanoid):Yield()
		assert(ok, "Never bound")
		expect(class.instance).toEqual(humanoid)
		expect(controller.binder:HasTag(humanoid)).toEqual(true)

		controller.destroy()
	end)

	it("binds the humanoid when a character is assigned after start", function()
		local controller = setup()
		controller.boot()

		local mock = controller.newMock(2)
		local character, humanoid = controller.newCharacter()
		controller.setCharacter(mock, character)

		local ok, class = controller.binder:Promise(humanoid):Yield()
		assert(ok, "Never bound")
		expect(class.instance).toEqual(humanoid)

		controller.destroy()
	end)

	it("binds a humanoid added to the character later", function()
		local controller = setup()
		controller.boot()

		local mock = controller.newMock()
		local character = controller.newCharacter(false)
		controller.setCharacter(mock, character)

		-- Let the tracker observe the humanoid-less character first, so the ChildAdded path is the one
		-- that discovers the humanoid.
		task.wait()

		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character

		local ok, class = controller.binder:Promise(humanoid):Yield()
		assert(ok, "Never bound")
		expect(class.instance).toEqual(humanoid)

		controller.destroy()
	end)

	it("unbinds and destroys the class when the character is destroyed", function()
		local controller = setup()
		controller.boot()

		local mock = controller.newMock()
		local character, humanoid = controller.newCharacter()
		controller.setCharacter(mock, character)

		local ok, class = controller.binder:Promise(humanoid):Yield()
		assert(ok, "Never bound")

		character:Destroy()
		awaitUnbound(controller.binder, humanoid)

		expect(controller.binder:Get(humanoid)).toBeNil()
		expect(class.destroyed).toEqual(true)

		controller.destroy()
	end)
end)

describe("PlayerHumanoidBinder:SetAutomaticTagging(false)", function()
	it("unbinds existing mock humanoids and rediscovers on re-enable", function()
		local controller = setup()
		controller.boot()

		local mock = controller.newMock()
		local character, humanoid = controller.newCharacter()
		controller.setCharacter(mock, character)

		local ok, class = controller.binder:Promise(humanoid):Yield()
		assert(ok, "Never bound")

		controller.binder:SetAutomaticTagging(false)
		awaitUnbound(controller.binder, humanoid)

		expect(controller.binder:Get(humanoid)).toBeNil()
		expect(class.destroyed).toEqual(true)

		controller.binder:SetAutomaticTagging(true)

		local rebound = controller.binder:Promise(humanoid):Yield()
		expect(rebound).toEqual(true)

		controller.destroy()
	end)

	it("stops discovering while disabled", function()
		local controller = setup()
		controller.boot()

		controller.binder:SetAutomaticTagging(false)

		local mock = controller.newMock()
		local character, humanoid = controller.newCharacter()
		controller.setCharacter(mock, character)

		task.wait(0.1)
		expect(controller.binder:Get(humanoid)).toBeNil()

		controller.destroy()
	end)
end)

describe("PlayerHumanoidBinder teardown", function()
	it("destroys bound classes when the service bag is destroyed", function()
		local controller = setup()
		controller.boot()

		local mock = controller.newMock()
		local character, humanoid = controller.newCharacter()
		controller.setCharacter(mock, character)

		local ok, class = controller.binder:Promise(humanoid):Yield()
		assert(ok, "Never bound")

		controller.destroy()

		expect(class.destroyed).toEqual(true)
	end)
end)
