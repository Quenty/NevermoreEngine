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
local MessagingServiceMock = require("MessagingServiceMock")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function newServiceBag(messagingService)
	local serviceBag = ServiceBag.new()
	local placeMessagingService = serviceBag:GetService(require("PlaceMessagingService"))
	serviceBag:Init()
	placeMessagingService:SetRobloxMessagingService(messagingService)
	serviceBag:Start()
	return serviceBag
end

describe("cross-server session messaging (close-session kick-out)", function()
	it("fires SessionCloseRequested on the session that receives a close-session message", function()
		local serviceBag = newServiceBag(MessagingServiceMock.new())
		local dataStoreMock = DataStoreMock.new()

		-- Two sessions on the same key, each with its own message helper (subscribes to its own topic).
		local sessionA = DataStore.new(dataStoreMock, "player_1")
		local sessionB = DataStore.new(dataStoreMock, "player_1")

		local helperA = DataStoreMessageHelper.new(serviceBag, sessionA)
		local helperB = DataStoreMessageHelper.new(serviceBag, sessionB)

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
			helperA:Destroy()
			helperB:Destroy()
			sessionA:Destroy()
			sessionB:Destroy()
			serviceBag:Destroy()
			return
		end

		local received = PromiseTestUtils.awaitValue(function()
			return closeRequested
		end, 15)
		expect(received).toEqual(true)

		helperA:Destroy()
		helperB:Destroy()
		sessionA:Destroy()
		sessionB:Destroy()
		serviceBag:Destroy()
	end)

	it("rejects sending a message to our own session", function()
		local serviceBag = newServiceBag(MessagingServiceMock.new())
		local dataStoreMock = DataStoreMock.new()
		local sessionA = DataStore.new(dataStoreMock, "player_1")
		local helperA = DataStoreMessageHelper.new(serviceBag, sessionA)

		expect(function()
			helperA:PromiseSendSessionMessage(game.PlaceId, game.JobId, sessionA:GetSessionId(), {
				type = "close-session",
				requesterSessionId = sessionA:GetSessionId(),
			})
		end).toThrow("Cannot message self")

		helperA:Destroy()
		sessionA:Destroy()
		serviceBag:Destroy()
	end)
end)
