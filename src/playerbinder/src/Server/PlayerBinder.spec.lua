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
local BinderTestUtils = require("BinderTestUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerBinder = require("PlayerBinder")
local PlayerMock = require("PlayerMock")
local PlayerMockService = require("PlayerMockService")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local specCounter = 0

local function setup(constructor: any?)
	specCounter += 1
	local suffix = specCounter

	local maid = Maid.new()

	local serviceBag = ServiceBag.new()
	local container = Instance.new("Folder")
	container.Name = "PlayerBinderSpecContainer"
	container.Parent = workspace

	local mocks: { Player } = {}
	local initialized = false
	local started = false

	local tag = string.format("PlayerBinderSpecTag_%d", suffix)
	local binder = PlayerBinder.new(tag, constructor or BinderTestUtils.makeTrackingClass())
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

	maid:GiveTask(function()
		if initialized then
			serviceBag:Destroy()
		end
		for _, mock in mocks do
			pcall(function()
				(mock :: Instance):Destroy()
			end)
		end
		container:Destroy()
	end)

	local function Destroy(_self)
		maid:DoCleaning()
	end

	local controller = {
		binder = binder,
		tag = tag,
		init = init,
		start = start,
		boot = boot,
		newMock = newMock,
		Destroy = Destroy,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("PlayerBinder.new()", function()
	it("is a Binder that reports its class name and tag", function()
		local binder = PlayerBinder.new("PlayerBinderMetaSpecTag", BinderTestUtils.makeTrackingClass())
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

		controller:Destroy()
	end)

	it("binds a player mock that exists before start", function()
		local controller = setup()

		controller.init()
		local mock = controller.newMock(1)
		controller.start()

		local class = PromiseTestUtils.awaitFulfilled(controller.binder:Promise(mock))
		expect(class.instance).toEqual(mock)

		controller:Destroy()
	end)

	it("binds a player mock created after start", function()
		local controller = setup()
		controller.boot()

		local mock = controller.newMock(2)

		local class = PromiseTestUtils.awaitFulfilled(controller.binder:Promise(mock))
		expect(class.instance).toEqual(mock)

		controller:Destroy()
	end)

	it("applies the binder's tag to the discovered mock", function()
		local controller = setup()
		controller.boot()

		local mock = controller.newMock()
		PromiseTestUtils.awaitFulfilled(controller.binder:Promise(mock))

		expect(controller.binder:HasTag(mock)).toEqual(true)

		controller:Destroy()
	end)

	it("binds each of several mocks to its own class", function()
		local controller = setup()
		controller.boot()

		local first = controller.newMock(1)
		local second = controller.newMock(2)

		local classA = PromiseTestUtils.awaitFulfilled(controller.binder:Promise(first))
		local classB = PromiseTestUtils.awaitFulfilled(controller.binder:Promise(second))

		expect(classA.instance).toEqual(first)
		expect(classB.instance).toEqual(second)
		expect(classA).never.toEqual(classB)
		expect(#controller.binder:GetAll()).toEqual(2)

		controller:Destroy()
	end)

	it("discovers a hand-built mock it did not create", function()
		local controller = setup()
		controller.boot()

		local foreignMock = PlayerMock.new({ UserId = 99 })
		foreignMock.Parent = workspace

		local class = PromiseTestUtils.awaitFulfilled(controller.binder:Promise(foreignMock))
		expect(class.instance).toEqual(foreignMock)

		foreignMock:Destroy()
		controller:Destroy()
	end)

	it("unbinds and destroys the class when the mock is destroyed", function()
		local controller = setup()
		controller.boot()

		local mock = controller.newMock()
		local class = PromiseTestUtils.awaitFulfilled(controller.binder:Promise(mock))

		mock:Destroy()
		expect(controller.binder:Get(mock)).toBeNil()

		expect(controller.binder:Get(mock)).toBeNil()
		expect(class.destroyed).toEqual(true)

		controller:Destroy()
	end)
end)
