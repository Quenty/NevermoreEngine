--!nonstrict
--[[
	@class RemotingObservableServerRelay.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerMock = require("PlayerMock")
local RemotingObservableConstants = require("RemotingObservableConstants")
local RemotingObservableServerRelay = require("RemotingObservableServerRelay")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local SUBSCRIBE = RemotingObservableConstants.OPCODE_SUBSCRIBE
local UNSUBSCRIBE = RemotingObservableConstants.OPCODE_UNSUBSCRIBE
local FIRE = RemotingObservableConstants.OPCODE_FIRE
local COMPLETE = RemotingObservableConstants.OPCODE_COMPLETE
local FAIL = RemotingObservableConstants.OPCODE_FAIL

local function setup(factory)
	local maid = Maid.new()

	local sent = {}
	local cleanups = 0

	local fakeRemoting = {}

	function fakeRemoting.Connect(_self, memberName, callback)
		fakeRemoting.connectedMember = memberName
		fakeRemoting.handler = callback

		return maid:Add(Maid.new())
	end

	function fakeRemoting.FireClient(_self, memberName, player, opcode, subscriptionKey, ...)
		table.insert(sent, {
			memberName = memberName,
			player = player,
			opcode = opcode,
			subscriptionKey = subscriptionKey,
			values = table.pack(...),
		})
	end

	local defaultFactory = function(_player, ...)
		local args = table.pack(...)

		return Observable.new(function(sub)
			sub:Fire(table.unpack(args, 1, args.n))

			return function()
				cleanups += 1
			end
		end)
	end

	local relay = RemotingObservableServerRelay.new(fakeRemoting, "Health", factory or defaultFactory)

	local controller = {}

	controller.relay = relay
	controller.sent = sent

	function controller.newPlayer(userId)
		local playerMock = PlayerMock.new({ UserId = userId })
		playerMock.Parent = Workspace
		maid:GiveTask(playerMock)

		return playerMock
	end

	function controller.request(player, opcode, subscriptionKey, ...)
		fakeRemoting.handler(player, opcode, subscriptionKey, ...)
	end

	function controller.cleanupCount()
		return cleanups
	end

	function controller.destroy()
		if getmetatable(relay) then
			relay:Destroy()
		end
		maid:DoCleaning()
	end

	return controller
end

describe("RemotingObservableServerRelay.new", function()
	it("listens on the reserved member for its own member name", function()
		local controller = setup()

		expect(controller.relay._reservedMemberName).toEqual(
			"Health" .. RemotingObservableConstants.RESERVED_MEMBER_SUFFIX
		)

		controller.destroy()
	end)
end)

describe("RemotingObservableServerRelay subscribe", function()
	it("relays each emission with the requesting subscription key", function()
		local controller = setup()
		local player = controller.newPlayer(1)

		controller.request(player, SUBSCRIBE, "c1", "hello")

		expect(#controller.sent).toEqual(1)
		expect(controller.sent[1].opcode).toEqual(FIRE)
		expect(controller.sent[1].subscriptionKey).toEqual("c1")
		expect(controller.sent[1].player).toBe(player)
		expect(controller.sent[1].values[1]).toEqual("hello")

		controller.destroy()
	end)

	it("relays every value of a multi-value emission", function()
		local controller = setup(function()
			return Observable.new(function(sub)
				sub:Fire(1, nil, "three")
				return nil
			end)
		end)
		local player = controller.newPlayer(1)

		controller.request(player, SUBSCRIBE, "c1")

		expect(controller.sent[1].values.n).toEqual(3)
		expect(controller.sent[1].values[1]).toEqual(1)
		expect(controller.sent[1].values[2]).toEqual(nil)
		expect(controller.sent[1].values[3]).toEqual("three")

		controller.destroy()
	end)

	it("routes emissions only to the player that subscribed", function()
		local controller = setup()
		local playerA = controller.newPlayer(1)
		local playerB = controller.newPlayer(2)

		controller.request(playerA, SUBSCRIBE, "c1", "for-a")
		controller.request(playerB, SUBSCRIBE, "c1", "for-b")

		expect(controller.sent[1].player).toBe(playerA)
		expect(controller.sent[1].values[1]).toEqual("for-a")
		expect(controller.sent[2].player).toBe(playerB)
		expect(controller.sent[2].values[1]).toEqual("for-b")

		controller.destroy()
	end)

	it("sends complete and forgets the subscription when the source completes", function()
		local controller = setup(function()
			return Observable.new(function(sub)
				sub:Complete()
				return nil
			end)
		end)
		local player = controller.newPlayer(1)

		controller.request(player, SUBSCRIBE, "c1")

		expect(controller.sent[1].opcode).toEqual(COMPLETE)
		expect(controller.relay._subscriptions[player]["c1"]).toEqual(nil)
		expect(controller.relay._subscriptionCount[player]).toEqual(0)

		controller.destroy()
	end)

	it("sends fail with the source error and forgets the subscription", function()
		local controller = setup(function()
			return Observable.new(function(sub)
				sub:Fail("nope")
				return nil
			end)
		end)
		local player = controller.newPlayer(1)

		controller.request(player, SUBSCRIBE, "c1")

		expect(controller.sent[1].opcode).toEqual(FAIL)
		expect(controller.sent[1].values[1]).toEqual("nope")
		expect(controller.relay._subscriptions[player]["c1"]).toEqual(nil)

		controller.destroy()
	end)

	it("fails the subscription when the factory errors", function()
		local controller = setup(function()
			error("factory blew up")
		end)
		local player = controller.newPlayer(1)

		controller.request(player, SUBSCRIBE, "c1")

		expect(controller.sent[1].opcode).toEqual(FAIL)
		expect(controller.relay._subscriptions[player]["c1"]).toEqual(nil)

		controller.destroy()
	end)

	it("fails the subscription when the factory returns a non-observable", function()
		local controller = setup(function()
			return { not_an = "observable" }
		end)
		local player = controller.newPlayer(1)

		controller.request(player, SUBSCRIBE, "c1")

		expect(controller.sent[1].opcode).toEqual(FAIL)
		expect(controller.relay._subscriptions[player]["c1"]).toEqual(nil)

		controller.destroy()
	end)

	it("does not retain a source that completes during subscribe", function()
		local controller = setup(function()
			return Observable.new(function(sub)
				sub:Fire(1)
				sub:Complete()
				return nil
			end)
		end)
		local player = controller.newPlayer(1)

		controller.request(player, SUBSCRIBE, "c1")

		expect(controller.relay._subscriptionCount[player]).toEqual(0)
		expect(next(controller.relay._subscriptions[player])).toEqual(nil)

		controller.destroy()
	end)
end)

describe("RemotingObservableServerRelay unsubscribe", function()
	it("runs the source cleanup and sends nothing back", function()
		local controller = setup()
		local player = controller.newPlayer(1)

		controller.request(player, SUBSCRIBE, "c1", "hello")
		local sentAfterSubscribe = #controller.sent

		controller.request(player, UNSUBSCRIBE, "c1")

		expect(controller.cleanupCount()).toEqual(1)
		expect(#controller.sent).toEqual(sentAfterSubscribe)
		expect(controller.relay._subscriptionCount[player]).toEqual(0)

		controller.destroy()
	end)

	it("ignores an unknown subscription key", function()
		local controller = setup()
		local player = controller.newPlayer(1)

		controller.request(player, UNSUBSCRIBE, "never-subscribed")

		expect(controller.cleanupCount()).toEqual(0)
		expect(#controller.sent).toEqual(0)

		controller.destroy()
	end)

	it("ignores a repeated unsubscribe", function()
		local controller = setup()
		local player = controller.newPlayer(1)

		controller.request(player, SUBSCRIBE, "c1")
		controller.request(player, UNSUBSCRIBE, "c1")
		controller.request(player, UNSUBSCRIBE, "c1")

		expect(controller.cleanupCount()).toEqual(1)

		controller.destroy()
	end)

	it("does not touch another player's identically keyed subscription", function()
		local controller = setup()
		local playerA = controller.newPlayer(1)
		local playerB = controller.newPlayer(2)

		controller.request(playerA, SUBSCRIBE, "c1")
		controller.request(playerB, SUBSCRIBE, "c1")

		controller.request(playerA, UNSUBSCRIBE, "c1")

		expect(controller.relay._subscriptionCount[playerA]).toEqual(0)
		expect(controller.relay._subscriptionCount[playerB]).toEqual(1)

		controller.destroy()
	end)
end)

describe("RemotingObservableServerRelay request validation", function()
	it("ignores a non-Instance player", function()
		local controller = setup()

		controller.request("not-a-player", SUBSCRIBE, "c1")

		expect(#controller.sent).toEqual(0)

		controller.destroy()
	end)

	it("ignores a non-string subscription key", function()
		local controller = setup()
		local player = controller.newPlayer(1)

		controller.request(player, SUBSCRIBE, 1)

		expect(#controller.sent).toEqual(0)

		controller.destroy()
	end)

	it("ignores an empty subscription key", function()
		local controller = setup()
		local player = controller.newPlayer(1)

		controller.request(player, SUBSCRIBE, "")

		expect(#controller.sent).toEqual(0)

		controller.destroy()
	end)

	it("ignores an oversized subscription key", function()
		local controller = setup()
		local player = controller.newPlayer(1)

		local oversized = string.rep("k", RemotingObservableConstants.MAX_SUBSCRIPTION_KEY_LENGTH + 1)
		controller.request(player, SUBSCRIBE, oversized)

		expect(#controller.sent).toEqual(0)

		controller.destroy()
	end)

	it("accepts a subscription key exactly at the length limit", function()
		local controller = setup()
		local player = controller.newPlayer(1)

		local atLimit = string.rep("k", RemotingObservableConstants.MAX_SUBSCRIPTION_KEY_LENGTH)
		controller.request(player, SUBSCRIBE, atLimit)

		expect(#controller.sent).toEqual(1)

		controller.destroy()
	end)

	it("ignores an unknown opcode", function()
		local controller = setup()
		local player = controller.newPlayer(1)

		controller.request(player, 999, "c1")

		expect(#controller.sent).toEqual(0)

		controller.destroy()
	end)

	it("ignores a duplicate subscription key", function()
		local controller = setup()
		local player = controller.newPlayer(1)

		controller.request(player, SUBSCRIBE, "c1", "first")
		controller.request(player, SUBSCRIBE, "c1", "second")

		expect(#controller.sent).toEqual(1)
		expect(controller.relay._subscriptionCount[player]).toEqual(1)

		controller.destroy()
	end)
end)

describe("RemotingObservableServerRelay subscription cap", function()
	it("fails the request that exceeds the per-player limit", function()
		local controller = setup()
		local player = controller.newPlayer(1)

		local limit = RemotingObservableConstants.MAX_SUBSCRIPTIONS_PER_PLAYER
		for index = 1, limit do
			controller.request(player, SUBSCRIBE, string.format("c%d", index))
		end

		local sentAtLimit = #controller.sent
		controller.request(player, SUBSCRIBE, "over")

		expect(controller.relay._subscriptionCount[player]).toEqual(limit)
		expect(controller.sent[sentAtLimit + 1].opcode).toEqual(FAIL)
		expect(controller.sent[sentAtLimit + 1].subscriptionKey).toEqual("over")

		controller.destroy()
	end)

	it("frees a slot once a subscription is released", function()
		local controller = setup()
		local player = controller.newPlayer(1)

		local limit = RemotingObservableConstants.MAX_SUBSCRIPTIONS_PER_PLAYER
		for index = 1, limit do
			controller.request(player, SUBSCRIBE, string.format("c%d", index))
		end

		controller.request(player, UNSUBSCRIBE, "c1")
		controller.request(player, SUBSCRIBE, "replacement")

		expect(controller.relay._subscriptionCount[player]).toEqual(limit)
		expect(controller.relay._subscriptions[player]["replacement"]).never.toEqual(nil)

		controller.destroy()
	end)

	it("budgets each player separately", function()
		local controller = setup()
		local playerA = controller.newPlayer(1)
		local playerB = controller.newPlayer(2)

		local limit = RemotingObservableConstants.MAX_SUBSCRIPTIONS_PER_PLAYER
		for index = 1, limit do
			controller.request(playerA, SUBSCRIBE, string.format("c%d", index))
		end

		controller.request(playerB, SUBSCRIBE, "c1")

		expect(controller.relay._subscriptionCount[playerA]).toEqual(limit)
		expect(controller.relay._subscriptionCount[playerB]).toEqual(1)

		controller.destroy()
	end)
end)

describe("RemotingObservableServerRelay teardown", function()
	it("drops every subscription belonging to a leaving player", function()
		local controller = setup()
		local player = controller.newPlayer(1)

		controller.request(player, SUBSCRIBE, "c1")
		controller.request(player, SUBSCRIBE, "c2")

		controller.relay:_cleanupPlayer(player)

		expect(controller.cleanupCount()).toEqual(2)
		expect(controller.relay._subscriptions[player]).toEqual(nil)
		expect(controller.relay._subscriptionCount[player]).toEqual(nil)

		controller.destroy()
	end)

	it("leaves other players untouched when one leaves", function()
		local controller = setup()
		local playerA = controller.newPlayer(1)
		local playerB = controller.newPlayer(2)

		controller.request(playerA, SUBSCRIBE, "c1")
		controller.request(playerB, SUBSCRIBE, "c1")

		controller.relay:_cleanupPlayer(playerA)

		expect(controller.relay._subscriptions[playerA]).toEqual(nil)
		expect(controller.relay._subscriptionCount[playerB]).toEqual(1)

		controller.destroy()
	end)

	it("completes every live subscription on destroy", function()
		local controller = setup()
		local playerA = controller.newPlayer(1)
		local playerB = controller.newPlayer(2)

		controller.request(playerA, SUBSCRIBE, "c1")
		controller.request(playerB, SUBSCRIBE, "c2")

		local sentBeforeDestroy = #controller.sent
		controller.relay:Destroy()

		local completes = 0
		for index = sentBeforeDestroy + 1, #controller.sent do
			if controller.sent[index].opcode == COMPLETE then
				completes += 1
			end
		end

		expect(completes).toEqual(2)
		expect(controller.cleanupCount()).toEqual(2)

		controller.destroy()
	end)

	it("stops accepting requests after destroy", function()
		local controller = setup()
		local player = controller.newPlayer(1)

		controller.relay:Destroy()

		expect(function()
			controller.request(player, SUBSCRIBE, "c1")
		end).toThrow()

		controller.destroy()
	end)
end)
