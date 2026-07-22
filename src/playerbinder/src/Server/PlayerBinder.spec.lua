--!strict
--[[
	Coverage for PlayerBinder, the Binder subclass that auto-tags every player. Real players never join
	a headless Open Cloud place, so the tests drive PlayerMocks: PlayerBinder.Start observes the
	PlayerMockService in its own ServiceBag, so a mock created through that service flows through
	discovery -> Tag -> bind exactly like a real join, with no test reaching in to Tag/Bind it by hand.
	Replication is place-wide like Players:GetPlayers() -- a mock created by any bag binds in every
	bag -- so tests destroy their mocks before the next test observes.

	Binders are booted the way production boots them: registered on a BinderProvider driven through a
	ServiceBag. Tags are global and the test place is shared across a batch run, so each test uses a
	distinct tag, parents its mocks under its own container, and destroys everything it creates so nothing
	leaks into a later test.

	@class PlayerBinder.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")
local Jest = require("Jest")
local PlayerBinder = require("PlayerBinder")
local PlayerMock = require("PlayerMock")
local PlayerMockService = require("PlayerMockService")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local specCounter = 0

-- Records its instance and whether it was destroyed. It ignores its constructor varargs: the ServiceBag
-- is injected as a constructor arg, and its Signals' strict __index makes jest's deep-equality traversal
-- throw, so the class must not retain it for toEqual to compare instances safely.
local function makeTrackingClass()
	local Class = {}
	Class.__index = Class
	Class.ClassName = "TrackingClass"

	function Class.new(inst)
		return setmetatable({ instance = inst, destroyed = false }, Class)
	end

	function Class:Destroy()
		self.destroyed = true
	end

	return Class
end

local function awaitUnbound(binder, inst)
	if binder:Get(inst) ~= nil then
		binder:GetClassRemovedSignal():Wait()
	end
end

local function setup(constructor: any?)
	specCounter += 1
	local suffix = specCounter

	local serviceBag = ServiceBag.new()
	local container = Instance.new("Folder")
	container.Name = "PlayerBinderSpecContainer"
	container.Parent = workspace

	local mocks: { Player } = {}
	local initialized = false
	local started = false

	local tag = string.format("PlayerBinderSpecTag_%d", suffix)
	local binder = PlayerBinder.new(tag, constructor or makeTrackingClass())
	-- Cast: the service's instance fields are assigned in Init, so its methods do not type-check
	-- against the exported module type.
	local playerMockService: any = serviceBag:GetService(PlayerMockService)

	local function init()
		assert(not initialized, "Already initialized")
		initialized = true

		local provider = BinderProvider.new(string.format("PlayerBinderSpecProvider_%d", suffix), function(self)
			self:Add(binder)
		end)
		serviceBag:GetService(provider)
		serviceBag:Init()
	end

	local function start()
		assert(initialized, "Call init() first")
		assert(not started, "Already started")
		started = true

		serviceBag:Start()
	end

	local function boot()
		init()
		start()
	end

	local function newMock(userId: number?): Player
		assert(initialized, "Call init() first -- mocks are created through the bag's PlayerMockService")

		local mock = playerMockService:CreatePlayer(if userId ~= nil then { UserId = userId } else nil)
		mock.Parent = container
		table.insert(mocks, mock)
		return mock
	end

	local function destroy()
		if initialized then
			serviceBag:Destroy()
		end
		for _, mock in mocks do
			pcall(function()
				(mock :: Instance):Destroy()
			end)
		end
		container:Destroy()
	end

	return {
		binder = binder,
		tag = tag,
		init = init,
		start = start,
		boot = boot,
		newMock = newMock,
		destroy = destroy,
	}
end

describe("PlayerBinder.new()", function()
	it("is a Binder that reports its class name and tag", function()
		local binder = PlayerBinder.new("PlayerBinderMetaSpecTag", makeTrackingClass())
		expect(Binder.isBinder(binder)).toEqual(true)
		expect((binder :: any).ClassName).toEqual("PlayerBinder")
		expect(binder:GetTag()).toEqual("PlayerBinderMetaSpecTag")
	end)
end)

describe("PlayerBinder mock discovery", function()
	it("starts cleanly with no players or mocks", function()
		local controller = setup()
		controller.boot()

		expect(controller.binder:GetAll()).toEqual({})

		controller.destroy()
	end)

	it("binds a player mock that exists before start", function()
		local controller = setup()

		controller.init()
		local mock = controller.newMock(1)
		controller.start()

		local ok, class = controller.binder:Promise(mock):Yield()
		assert(ok, "Never bound")
		expect(class.instance).toEqual(mock)

		controller.destroy()
	end)

	it("binds a player mock created after start", function()
		local controller = setup()
		controller.boot()

		local mock = controller.newMock(2)

		local ok, class = controller.binder:Promise(mock):Yield()
		assert(ok, "Never bound")
		expect(class.instance).toEqual(mock)

		controller.destroy()
	end)

	it("applies the binder's tag to the discovered mock", function()
		local controller = setup()
		controller.boot()

		local mock = controller.newMock()
		assert((controller.binder:Promise(mock):Yield()), "Never bound")

		expect(controller.binder:HasTag(mock)).toEqual(true)

		controller.destroy()
	end)

	it("binds each of several mocks to its own class", function()
		local controller = setup()
		controller.boot()

		local first = controller.newMock(1)
		local second = controller.newMock(2)

		local okA, classA = controller.binder:Promise(first):Yield()
		local okB, classB = controller.binder:Promise(second):Yield()
		assert(okA and okB, "Never bound")

		expect(classA.instance).toEqual(first)
		expect(classB.instance).toEqual(second)
		expect(classA).never.toEqual(classB)
		expect(#controller.binder:GetAll()).toEqual(2)

		controller.destroy()
	end)

	it("discovers a hand-built mock it did not create", function()
		local controller = setup()
		controller.boot()

		local foreignMock = PlayerMock.new({ UserId = 99 })
		foreignMock.Parent = workspace

		local ok, class = controller.binder:Promise(foreignMock):Yield()
		assert(ok, "Never bound")
		expect(class.instance).toEqual(foreignMock)

		foreignMock:Destroy()
		controller.destroy()
	end)

	it("unbinds and destroys the class when the mock is destroyed", function()
		local controller = setup()
		controller.boot()

		local mock = controller.newMock()
		local ok, class = controller.binder:Promise(mock):Yield()
		assert(ok, "Never bound")

		mock:Destroy()
		awaitUnbound(controller.binder, mock)

		expect(controller.binder:Get(mock)).toBeNil()
		expect(class.destroyed).toEqual(true)

		controller.destroy()
	end)
end)
