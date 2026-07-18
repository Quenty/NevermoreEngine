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

local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("cross-server session messaging (close-session kick-out)", function()
	it("fires SessionCloseRequested on the session that receives a close-session message", function()
		local controller = DataStoreTestUtils.setup()

		-- Two sessions on the same key, each with its own message helper (subscribes to its own topic).
		local sessionA = controller.newDataStore()
		local sessionB = controller.newDataStore()

		local _helperA = controller.newMessageHelper(sessionA)
		local helperB = controller.newMessageHelper(sessionB)

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
		local controller = DataStoreTestUtils.setup()
		local sessionA = controller.newDataStore()
		local helperA = controller.newMessageHelper(sessionA)

		expect(function()
			helperA:PromiseSendSessionMessage(game.PlaceId, game.JobId, sessionA:GetSessionId(), {
				type = "close-session",
				requesterSessionId = sessionA:GetSessionId(),
			})
		end).toThrow("Cannot message self")

		controller:destroy()
	end)
end)
