--!strict
--[[
	Dual-realm coverage for fact replication. Boots a SERVER and a CLIENT ServiceBag in the same
	DataModel and drives facts across the production remoting path -- no stub in between, so what is
	asserted is what ships.

	The two realms register the same fact names with different answers, which is the arrangement the
	whole package rests on: a fact the client cannot resolve reads unresolved there until the server
	says otherwise.

	@class AccessReplicationServiceClient.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local AccessDataService = require("AccessDataService")
local AccessFact = require("AccessFact")
local AccessFactServerOverrideBehavior = require("AccessFactServerOverrideBehavior")
local AccessFeature = require("AccessFeature")
local AccessReplicationService = require("AccessReplicationService")
local AccessReplicationServiceClient = require("AccessReplicationServiceClient")
local AccessStateUtils = require("AccessStateUtils")
local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMockService = require("PlayerMockService")
local PlayerMockServiceClient = require("PlayerMockServiceClient")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local ON_DISALLOW = AccessFactServerOverrideBehavior.SERVER_OVERRIDE_ON_DISALLOW_ONLY
local NONE = AccessFactServerOverrideBehavior.SERVER_OVERRIDE_NONE

local specCounter = 0

-- Replication crosses a real RemoteEvent, so a value arrives a step later rather than during the call
-- that caused it. Waited for rather than assumed, and bounded so a failure reads as a failure.
local function waitForValue(read: () -> boolean?, expected: boolean?): boolean?
	local deadline = os.clock() + 2

	repeat
		local value = read()
		if value == expected then
			return value
		end
		task.wait()
	until os.clock() > deadline

	return read()
end

local function newFact(maid: Maid.Maid, accessDataService: any, factName: string, initial: boolean?, behavior: string?)
	local valueObject = maid:Add(ValueObject.new(initial)) :: any
	maid:GiveTask(accessDataService:RegisterFact(AccessFact.new(factName, {
		resolve = function()
			return valueObject
		end,
		serverOverrideBehavior = behavior,
	})))
	return valueObject
end

local function setup()
	specCounter += 1

	local maid = Maid.new()

	local serverBag = maid:Add(ServiceBag.new())
	local serverAccess: any = serverBag:GetService(AccessDataService)
	local replicationService: any = serverBag:GetService(AccessReplicationService)
	local playerMockService: any = serverBag:GetService(PlayerMockService)
	serverBag:Init()
	serverBag:Start()

	local mock = playerMockService:CreatePlayer({ UserId = 88200400 + specCounter })

	local clientBag = maid:Add(ServiceBag.new())
	local clientAccess: any = clientBag:GetService(AccessDataService)
	clientBag:GetService(AccessReplicationServiceClient)
	local playerMockServiceClient: any = clientBag:GetService(PlayerMockServiceClient)
	clientBag:Init()
	playerMockServiceClient:SetLocalPlayer(mock)
	clientBag:Start()

	return {
		maid = maid,
		mock = mock,
		serverAccess = serverAccess,
		clientAccess = clientAccess,
		replicationService = replicationService,
		serverFact = function(factName: string, initial: boolean?)
			return newFact(maid, serverAccess, factName, initial)
		end,
		clientFact = function(factName: string, initial: boolean?, behavior: string?)
			return newFact(maid, clientAccess, factName, initial, behavior)
		end,
		replicate = function()
			replicationService:AddPlayer(mock)
		end,
		-- What a joining client does on start. Applied through the client service so the production path
		-- is the one under test.
		requestSnapshot = function()
			for factName, box in replicationService:GetFactValues(mock) do
				clientAccess:SetServerFactValue(mock, factName, box.value)
			end
		end,
		readClient = function(factName: string): () -> boolean?
			local last = nil
			maid:GiveTask(clientAccess:ObserveFactReport(mock, factName):Subscribe(function(report)
				last = report
			end))
			return function()
				return (last :: any).value
			end
		end,
		destroy = function(_self)
			-- Client first: the server bag owns the mock, and tearing that out from under a live client
			-- is not something production ever does.
			maid:DoCleaning()
		end,
	}
end

describe("fact replication across realms", function()
	it("carries an answer the client could not resolve for itself", function()
		local controller = setup()
		controller.serverFact("serverOnly", true)
		controller.clientFact("serverOnly", nil)

		local read = controller.readClient("serverOnly")
		expect(read()).toEqual(nil)

		controller.replicate()

		expect(waitForValue(read, true)).toEqual(true)

		controller:destroy()
	end)

	it("follows the server as its answer changes", function()
		-- The client cannot answer this one at all, so the server settles it either way -- a behavior only
		-- governs overriding a local answer, and there is none here.
		local controller = setup()
		local serverValue = controller.serverFact("serverOnly", false)
		controller.clientFact("serverOnly", nil)

		local read = controller.readClient("serverOnly")
		controller.replicate()
		expect(waitForValue(read, false)).toEqual(false)

		serverValue.Value = true
		expect(waitForValue(read, true)).toEqual(true)

		controller:destroy()
	end)

	it("cannot take access the client already had, under the default behavior", function()
		local controller = setup()
		controller.serverFact("ownsGame", false)
		controller.clientFact("ownsGame", true)

		local read = controller.readClient("ownsGame")
		controller.replicate()

		expect(waitForValue(read, true)).toEqual(true)

		controller:destroy()
	end)

	it("takes access away when the fact asks it to", function()
		local controller = setup()
		controller.serverFact("notBanned", false)
		controller.clientFact("notBanned", true, ON_DISALLOW)

		local read = controller.readClient("notBanned")
		controller.replicate()

		expect(waitForValue(read, false)).toEqual(false)

		controller:destroy()
	end)

	it("replicates even when the client declines to be overridden", function()
		-- Replication is unconditional; only the overriding is configurable.
		local controller = setup()
		controller.serverFact("clientKnows", true)
		controller.clientFact("clientKnows", false, NONE)

		local last = nil
		controller.maid:GiveTask(
			controller.clientAccess:ObserveFactReport(controller.mock, "clientKnows"):Subscribe(function(report)
				last = report
			end)
		)

		controller.replicate()

		local deadline = os.clock() + 2
		while (last :: any).serverValue == nil and os.clock() < deadline do
			task.wait()
		end

		expect((last :: any).serverValue).toEqual(true)
		expect((last :: any).value).toEqual(false)

		controller:destroy()
	end)

	it("opens a feature on the client that only the server could grant", function()
		local controller = setup()
		controller.serverFact("serverOnly", true)
		controller.clientFact("serverOnly", nil)

		local feature = AccessFeature.anyOf("chapters", { "serverOnly" })
		controller.maid:GiveTask(controller.clientAccess:RegisterFeature(feature))

		local last = nil
		controller.maid:GiveTask(
			controller.clientAccess:ObserveFeature(controller.mock, feature):Subscribe(function(state)
				last = state
			end)
		)

		expect(AccessStateUtils.isUnresolved(last :: any)).toEqual(true)

		controller.replicate()

		local deadline = os.clock() + 2
		while not AccessStateUtils.isAllowed(last :: any) and os.clock() < deadline do
			task.wait()
		end

		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(true)

		controller:destroy()
	end)

	it("hands a joining client the state it missed, without waiting for a change", function()
		-- Connecting to the change event is not enough: a client that connects after the server has
		-- already resolved something hears nothing until the next change, and for a fact that never
		-- changes again that is never. The snapshot is what closes that race.
		local controller = setup()
		controller.serverFact("serverOnly", true)
		controller.clientFact("serverOnly", nil)

		local read = controller.readClient("serverOnly")
		controller.requestSnapshot()

		expect(waitForValue(read, true)).toEqual(true)

		controller:destroy()
	end)
end)
