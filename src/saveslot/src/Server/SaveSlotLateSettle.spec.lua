--!strict
--[[
	The per-player selection chain (slots loaded -> teleport read -> default slot) runs against
	datastore reads that can settle long after the player left — session-lock and datastore
	retries outlive a leave. A continuation that then calls into the destroyed
	(metatable-stripped) HasSaveSlots binder throws "attempt to call missing method ..." as a
	stray error that fails the whole run. The chain must consume a late settle silently: every
	hop is maid-owned (cancelled with the binder's brio) and re-checks the binder is alive.

	@class SaveSlotLateSettle.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local afterEach = Jest.Globals.afterEach
local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local USER_ID = 636363

-- Every datastore read yields this long, so the spec can land the unbind inside a chosen
-- read's in-flight window.
local READ_YIELD_SECONDS = 0.5

local activeController: any = nil

afterEach(function()
	-- Safety net for a failing test: destroy is idempotent, so this is a no-op after the test's
	-- own controller:destroy() and a full teardown when an assertion threw before reaching it.
	if activeController then
		local controller = activeController
		activeController = nil
		controller:destroy()
	end
end)

local function setup()
	local maid = Maid.new()

	local mock = DataStoreMock.new()
	mock:SetYieldTime(READ_YIELD_SECONDS)

	local serviceBag = maid:Add(ServiceBag.new())
	local playerDataStoreService: any = serviceBag:GetService(require("PlayerDataStoreService"))
	local hasSaveSlotsBinder: any = serviceBag:GetService(require("HasSaveSlots"))
	serviceBag:GetService(require("SaveSlotService"))
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(mock)
	serviceBag:Start()

	local fakePlayer = maid:Add(PlayerMock.new({ UserId = USER_ID }))
	fakePlayer.Parent = Workspace

	local destroyed = false
	local controller: any
	controller = {
		hasSaveSlotsBinder = hasSaveSlotsBinder,
		fakePlayer = fakePlayer,
		destroy = function(self: any)
			if destroyed then
				return
			end
			destroyed = true
			if activeController == self then
				activeController = nil
			end
			serviceBag:Destroy()
			maid:DoCleaning()
			-- Any straggler continuation blows up here, inside the test that owns it, rather
			-- than as flake in a later suite.
			task.wait(READ_YIELD_SECONDS * 3)
		end,
	}
	activeController = controller

	return controller
end

describe("SaveSlotService selection chain vs a player who leaves mid-load", function()
	it("consumes a slots-load still pending when the binder dies", function()
		local controller = setup()

		local hasSaveSlots =
			assert(controller.hasSaveSlotsBinder:Bind(controller.fakePlayer), "Failed to bind HasSaveSlots")
		local slotsLoaded = hasSaveSlots:PromiseSlotsLoaded()

		-- Let the service's chain attach to the (still pending) load, then "leave".
		task.wait()
		expect(PromiseTestUtils.awaitSettled(slotsLoaded, 0)).toEqual(false)
		controller.hasSaveSlotsBinder:Unbind(controller.fakePlayer)

		controller:destroy()
	end)

	it("consumes a default-slot read that settles after the binder died", function()
		local controller = setup()

		local hasSaveSlots =
			assert(controller.hasSaveSlotsBinder:Bind(controller.fakePlayer), "Failed to bind HasSaveSlots")

		-- Play the chain forward to the default-slot resolution: slots loaded, teleport read
		-- consumed, and the last-active-slot datastore read now in its in-flight window.
		expect(PromiseTestUtils.awaitSettled(hasSaveSlots:PromiseSlotsLoaded(), 10)).toEqual(true)
		task.wait()

		-- The player leaves inside that window; the read settles after the binder is gone.
		-- With the regression, the settle's continuation calls the destroyed binder and a
		-- stray "attempt to call missing method" error fails the run.
		controller.hasSaveSlotsBinder:Unbind(controller.fakePlayer)

		controller:destroy()
	end)
end)
