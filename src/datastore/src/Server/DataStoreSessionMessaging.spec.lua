--!nonstrict
--[[
	Cross-server session messaging: one session asks another to close (the "you got kicked because
	you activated elsewhere" flow). Modeled with two DataStoreMessageHelpers (session A and B) over
	one server. A MessagingServiceMock is injected into the PlaceMessagingService and loops messages
	back in-process, so B's close-session request is delivered to A's subscription without ever
	touching the real MessagingService.

	@class DataStoreSessionMessaging.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStoreMessageHelper = require("DataStoreMessageHelper")
local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local Maid = require("Maid")
local MessagingServiceMock = require("MessagingServiceMock")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Builds a ServiceBag with an in-process MessagingServiceMock plus sessions and helpers over a shared
-- DataStoreMock, all owned by a Maid, so destroy() tears down every object the test created.
-- newSession() builds a session store; newHelper(session) wires a message helper to it off the bag.
local function setup()
	local maid = Maid.new()

	local serviceBag = maid:Add(ServiceBag.new())
	local placeMessagingService = serviceBag:GetService(require("PlaceMessagingService"))
	serviceBag:Init()
	placeMessagingService:SetRobloxMessagingService(MessagingServiceMock.new())
	serviceBag:Start()

	local dataStoreMock = DataStoreMock.new()

	local function newSession()
		return maid:Add(DataStore.new(dataStoreMock, "player_1"))
	end

	local function newHelper(session)
		return maid:Add(DataStoreMessageHelper.new(serviceBag, session))
	end

	return {
		newSession = newSession,
		newHelper = newHelper,
		destroy = function()
			maid:DoCleaning()
		end,
	}
end

describe("cross-server session messaging (close-session kick-out)", function()
	it("fires SessionCloseRequested on the session that receives a close-session message", function()
		local controller = setup()

		-- Two sessions on the same key, each with its own message helper (subscribes to its own topic).
		local sessionA = controller.newSession()
		local sessionB = controller.newSession()

		local _helperA = controller.newHelper(sessionA)
		local helperB = controller.newHelper(sessionB)

		local closeRequested = false
		sessionA.SessionCloseRequested:Connect(function()
			closeRequested = true
		end)

		-- B asks A to close (as if A just teleported / activated on server B).
		local sendPromise = helperB:PromiseSendSessionMessage(game.PlaceId, game.JobId, sessionA:GetSessionId(), {
			type = "close-session",
			requesterSessionId = sessionB:GetSessionId(),
		})

		if not PromiseTestUtils.awaitSettled(sendPromise, 10) then
			expect("message send hung").toEqual("message send settled")
			controller:destroy()
			return
		end

		local received = PromiseTestUtils.awaitValue(function()
			return closeRequested
		end, 15)
		expect(received).toEqual(true)

		controller:destroy()
	end)

	it("rejects sending a message to our own session", function()
		local controller = setup()
		local sessionA = controller.newSession()
		local helperA = controller.newHelper(sessionA)

		expect(function()
			helperA:PromiseSendSessionMessage(game.PlaceId, game.JobId, sessionA:GetSessionId(), {
				type = "close-session",
				requesterSessionId = sessionA:GetSessionId(),
			})
		end).toThrow("Cannot message self")

		controller:destroy()
	end)
end)
