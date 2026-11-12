--!strict
--[[
	@class DiscoveryStateMachine.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DiscoveryStateMachine = require("DiscoveryStateMachine")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(config: DiscoveryStateMachine.DiscoveryConfig?): any
	local controller
	controller = {
		foundPort = nil :: number?,
		connectSucceeds = true,
		scans = {} :: { { ports: { number }, timeoutSec: number } },
		connectUrls = {} :: { string },
		stateChanges = {} :: { string },
		connected = {} :: { { connection: any, port: number } },
		disconnectReasons = {} :: { string },
	}

	controller.machine = DiscoveryStateMachine.new(config, {
		scanPortsAsync = function(ports, timeoutSec)
			table.insert(controller.scans, { ports = ports, timeoutSec = timeoutSec })
			return controller.foundPort, nil
		end,
		connectWebSocket = function(url)
			table.insert(controller.connectUrls, url)
			if controller.connectSucceeds then
				return true, { url = url }
			end
			return false, nil
		end,
		onStateChange = function(oldState, newState)
			table.insert(controller.stateChanges, `{oldState}->{newState}`)
		end,
		onConnected = function(connection, port)
			table.insert(controller.connected, { connection = connection, port = port })
		end,
		onDisconnected = function(reason)
			table.insert(controller.disconnectReasons, reason or "nil")
		end,
	})

	return controller
end

describe("DiscoveryStateMachine.new()", function()
	it("should start idle", function()
		local controller = setup()

		expect(controller.machine:GetState()).toEqual("idle")
	end)
end)

describe("DiscoveryStateMachine:Start()", function()
	it("should move from idle to searching", function()
		local controller = setup()

		controller.machine:Start()

		expect(controller.machine:GetState()).toEqual("searching")
		expect(controller.stateChanges).toEqual({ "idle->searching" })
	end)

	it("should do nothing when already started", function()
		local controller = setup()
		controller.machine:Start()

		controller.machine:Start()

		expect(controller.stateChanges).toEqual({ "idle->searching" })
	end)
end)

describe("DiscoveryStateMachine:PollAsync()", function()
	it("should not scan while idle", function()
		local controller = setup()

		controller.machine:PollAsync(1)

		expect(#controller.scans).toEqual(0)
	end)

	it("should scan the default port range with the remaining time", function()
		local controller = setup()
		controller.machine:Start()

		controller.machine:PollAsync(1.5)

		expect(controller.scans).toEqual({
			{ ports = { 38741, 38742, 38743, 38744 }, timeoutSec = 1.5 },
		})
	end)

	it("should scan a configured port range", function()
		local controller = setup({ portRange = { min = 5000, max = 5001 } })
		controller.machine:Start()

		controller.machine:PollAsync(1)

		expect(controller.scans[1].ports).toEqual({ 5000, 5001 })
	end)

	it("should not scan without time left", function()
		local controller = setup()
		controller.machine:Start()

		controller.machine:PollAsync(0)

		expect(#controller.scans).toEqual(0)
	end)

	it("should wait the poll interval before scanning again after a miss", function()
		local controller = setup({ pollIntervalSec = 60 })
		controller.machine:Start()

		controller.machine:PollAsync(1)
		controller.machine:PollAsync(1)

		expect(#controller.scans).toEqual(1)
		expect(controller.machine:GetState()).toEqual("searching")
	end)

	it("should connect to the port that answered", function()
		local controller = setup()
		controller.foundPort = 38743
		controller.machine:Start()

		controller.machine:PollAsync(1)

		expect(controller.machine:GetState()).toEqual("connected")
		expect(controller.connectUrls).toEqual({ "ws://localhost:38743/plugin" })
		expect(controller.stateChanges).toEqual({ "idle->searching", "searching->connecting", "connecting->connected" })
		expect(controller.connected[1].port).toEqual(38743)
		expect(controller.connected[1].connection).toEqual({ url = "ws://localhost:38743/plugin" })
	end)

	it("should go back to searching when the connection fails", function()
		local controller = setup({ pollIntervalSec = 60 })
		controller.foundPort = 38741
		controller.connectSucceeds = false
		controller.machine:Start()

		controller.machine:PollAsync(1)
		controller.machine:PollAsync(1)

		expect(controller.machine:GetState()).toEqual("searching")
		expect(#controller.scans).toEqual(1)
		expect(#controller.connected).toEqual(0)
	end)

	it("should not scan while connected", function()
		local controller = setup()
		controller.foundPort = 38741
		controller.machine:Start()
		controller.machine:PollAsync(1)

		controller.machine:PollAsync(1)

		expect(#controller.scans).toEqual(1)
	end)
end)

describe("DiscoveryStateMachine:HandleDisconnect()", function()
	it("should report the reason and scan again right away", function()
		local controller = setup({ pollIntervalSec = 60 })
		controller.foundPort = 38741
		controller.machine:Start()
		controller.machine:PollAsync(1)

		controller.machine:HandleDisconnect("closed")
		controller.machine:PollAsync(1)

		expect(controller.disconnectReasons).toEqual({ "closed" })
		expect(#controller.scans).toEqual(2)
		expect(controller.machine:GetState()).toEqual("connected")
	end)

	it("should do nothing unless connected", function()
		local controller = setup()
		controller.machine:Start()

		controller.machine:HandleDisconnect("closed")

		expect(controller.disconnectReasons).toEqual({})
		expect(controller.machine:GetState()).toEqual("searching")
	end)
end)

describe("DiscoveryStateMachine:Stop()", function()
	it("should return to idle from searching without reporting a disconnect", function()
		local controller = setup()
		controller.machine:Start()

		controller.machine:Stop()

		expect(controller.machine:GetState()).toEqual("idle")
		expect(controller.disconnectReasons).toEqual({})
	end)

	it("should report a stopped disconnect when connected", function()
		local controller = setup()
		controller.foundPort = 38741
		controller.machine:Start()
		controller.machine:PollAsync(1)

		controller.machine:Stop()

		expect(controller.machine:GetState()).toEqual("idle")
		expect(controller.disconnectReasons).toEqual({ "stopped" })
	end)

	it("should allow starting again", function()
		local controller = setup()
		controller.machine:Start()
		controller.machine:Stop()

		controller.machine:Start()

		expect(controller.machine:GetState()).toEqual("searching")
	end)
end)
