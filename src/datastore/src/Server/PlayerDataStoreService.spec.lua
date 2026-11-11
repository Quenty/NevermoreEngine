--!nonstrict
--[[
	@class PlayerDataStoreService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(mock)
	local maid = Maid.new()

	local serviceBag = maid:Add(ServiceBag.new())
	local bindToCloseService = serviceBag:GetService(require("BindToCloseService"))
	local service = serviceBag:GetService(require("PlayerDataStoreService"))
	serviceBag:Init()

	if mock then
		service:SetRobloxDataStore(mock)
		serviceBag:Start()
	end

	local controller = {
		service = service,
		mock = mock,
		bindToCloseService = bindToCloseService,
		Destroy = function(_self)
			PromiseTestUtils.awaitFulfilled(bindToCloseService:PromiseClose())
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("PlayerDataStoreService.PromiseDataStore", function()
	it("should resolve a datastore and load successfully against a healthy mock", function()
		local controller = setup(DataStoreMock.new())

		local dataStore = PromiseTestUtils.awaitFulfilled(controller.service:PromiseDataStore(1), 10)
		expect(dataStore).never.toBeNil()

		expect(PromiseTestUtils.awaitFulfilled(dataStore:PromiseLoadSuccessful(), 10)).toEqual(true)

		controller:Destroy()
	end)
end)

describe("PlayerDataStoreService configuration guards", function()
	it("should throw when SetDataStoreName is called after start", function()
		local controller = setup(DataStoreMock.new())

		expect(function()
			controller.service:SetDataStoreName("X")
		end).toThrow("Already started, cannot configure")

		controller:Destroy()
	end)

	it("should throw when SetDataStoreScope is called after start", function()
		local controller = setup(DataStoreMock.new())

		expect(function()
			controller.service:SetDataStoreScope("X")
		end).toThrow("Already started, cannot configure")

		controller:Destroy()
	end)

	it("should throw when SetRobloxDataStore is called after the manager is built", function()
		local controller = setup(DataStoreMock.new())

		expect(PromiseTestUtils.awaitSettled(controller.service:PromiseDataStore(1), 10)).toEqual(true)

		expect(function()
			controller.service:SetRobloxDataStore(controller.mock)
		end).toThrow("Already built manager")

		controller:Destroy()
	end)

	it("should throw when SetRobloxDataStore is given a bad datastore", function()
		local controller = setup()

		expect(function()
			controller.service:SetRobloxDataStore(nil)
		end).toThrow("Bad robloxDataStore")

		expect(function()
			controller.service:SetRobloxDataStore({})
		end).toThrow("Bad robloxDataStore")

		controller:Destroy()
	end)
end)

describe("PlayerDataStoreService.PromiseAddRemovingCallback", function()
	it("should resolve after registering the removing callback", function()
		local controller = setup(DataStoreMock.new())

		PromiseTestUtils.awaitFulfilled(controller.service:PromiseAddRemovingCallback(function() end), 10)

		controller:Destroy()
	end)
end)

describe("PlayerDataStoreService failure handling", function()
	it("surfaces a datastore failure to the player fast instead of hanging", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local controller = setup(mock)

		local dataStore = PromiseTestUtils.awaitFulfilled(controller.service:PromiseDataStore(1), 10)
		expect(dataStore).never.toBeNil()

		expect(PromiseTestUtils.awaitFulfilled(dataStore:PromiseLoadSuccessful(), 5)).toEqual(false)

		controller:Destroy()
	end)
end)

describe("PlayerDataStoreService server shutdown", function()
	it("saves the staged data and destroys the store when the server closes", function()
		local controller = setup(DataStoreMock.new())

		local dataStore = PromiseTestUtils.awaitFulfilled(controller.service:PromiseDataStore(1), 10)

		expect(PromiseTestUtils.awaitSettled(dataStore:PromiseLoadSuccessful(), 10)).toEqual(true)

		dataStore:Store("coins", 7)

		PromiseTestUtils.awaitFulfilled(controller.bindToCloseService:PromiseClose(), 10)

		local raw = controller.mock:GetRaw("1")
		expect(raw).never.toBeNil()
		expect(raw.coins).toEqual(7)
		expect(getmetatable(dataStore)).toBeNil()

		controller:Destroy()
	end)
end)

describe("PlayerDataStoreService datastore configuration", function()
	-- The shared setup() starts the bag as soon as it has a mock, and these setters must land between
	-- Init and Start -- the same window SetDataStoreName uses.
	local function setupConfigured(configure)
		local maid = Maid.new()

		local mock = DataStoreMock.new()
		local serviceBag = maid:Add(ServiceBag.new())
		local bindToCloseService = serviceBag:GetService(require("BindToCloseService"))
		local service = serviceBag:GetService(require("PlayerDataStoreService"))
		serviceBag:Init()

		service:SetRobloxDataStore(mock)
		configure(service)
		serviceBag:Start()

		local controller = {
			service = service,
			mock = mock,
			Destroy = function(_self)
				PromiseTestUtils.awaitFulfilled(bindToCloseService:PromiseClose())
				maid:DoCleaning()
			end,
		}

		maid:GiveTask(JestUtils.afterThis(controller))

		return controller
	end

	it("forwards configuration through to the datastores the manager creates", function()
		local retryOptions = { exponential = 1, initialWaitTime = 0.1, maxAttempts = 2, printWarning = false }
		local controller = setupConfigured(function(service)
			service:SetAutoSaveTimeSeconds(14)
			service:SetLoadRetryOptions(retryOptions)
			service:SetSessionMessagingCloseDelaySeconds(0.5)
		end)

		local dataStore = PromiseTestUtils.awaitFulfilled(controller.service:PromiseDataStore(1), 10)

		expect((dataStore:GetAutoSaveTimeSeconds())).toEqual(14)
		expect((dataStore:GetLoadRetryOptions())).toEqual(retryOptions)
		expect((dataStore:GetSessionMessagingCloseDelaySeconds())).toEqual(0.5)

		controller:Destroy()
	end)

	it("rejects configuration after start", function()
		local controller = setupConfigured(function() end)

		expect(function()
			controller.service:SetAutoSaveTimeSeconds(14)
		end).toThrow()
		expect(function()
			controller.service:SetLoadRetryOptions({ initialWaitTime = 1, maxAttempts = 2, printWarning = false })
		end).toThrow()
		expect(function()
			controller.service:SetSessionMessagingCloseDelaySeconds(0.5)
		end).toThrow()

		controller:Destroy()
	end)
end)
