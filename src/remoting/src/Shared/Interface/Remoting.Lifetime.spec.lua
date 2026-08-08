--!nonstrict
--[[
	@class Remoting.Lifetime.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local Observable = require("Observable")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local Remoting = require("Remoting")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function countTasks(maid)
	local count = 0
	for _ in maid._tasks do
		count += 1
	end

	return count
end

local function setup()
	local instance = Instance.new("Folder")

	local server = Remoting.Server.new(instance, "Lifetime")
	server._useDummyObject = true

	local client = Remoting.Client.new(instance, "Lifetime")
	client._useDummyObject = true

	local playerMock = PlayerMock.new({ UserId = 12345 })
	playerMock.Parent = Workspace
	PlayerMock.setMockedLocalPlayer(playerMock)

	local serverDestroyed = false
	local clientDestroyed = false

	local controller = {}

	controller.instance = instance
	controller.server = server
	controller.client = client
	controller.player = playerMock

	function controller.destroyServer()
		serverDestroyed = true
		server:Destroy()
	end

	function controller.destroyClient()
		clientDestroyed = true
		client:Destroy()
	end

	function controller.serverTaskCount()
		return countTasks(server._maid)
	end

	function controller.clientTaskCount()
		return countTasks(client._maid)
	end

	function controller.container()
		return instance:FindFirstChildOfClass("Configuration")
	end

	function controller.settle(promise)
		return PromiseTestUtils.awaitSettled(promise)
	end

	function controller.destroy()
		if not clientDestroyed then
			client:Destroy()
		end
		if not serverDestroyed then
			server:Destroy()
		end
		PlayerMock.setMockedLocalPlayer(nil)
		playerMock:Destroy()
		instance:Destroy()
	end

	return controller
end

describe("Remoting.Connect lifetime", function()
	it("registers a task on the remoting and releases it when the connection is cleaned", function()
		local controller = setup()

		controller.server:Connect("Ping", function() end):DoCleaning()

		local before = controller.serverTaskCount()
		local connectMaid = controller.server:Connect("Ping", function() end)

		expect(controller.serverTaskCount()).toEqual(before + 1)

		connectMaid:DoCleaning()

		expect(controller.serverTaskCount()).toEqual(before)

		controller.destroy()
	end)

	it("stops delivering to the callback once the connection is cleaned", function()
		local controller = setup()

		local calls = 0
		local connectMaid = controller.server:Connect("Ping", function()
			calls += 1
		end)

		controller.client:FireServer("Ping")
		expect(PromiseTestUtils.awaitValue(function()
			return calls == 1
		end)).toEqual(true)

		connectMaid:DoCleaning()
		controller.client:FireServer("Ping")

		expect(PromiseTestUtils.awaitValue(function()
			return calls == 1
		end)).toEqual(true)

		controller.destroy()
	end)

	it("does not accumulate tasks across repeated connect and release cycles", function()
		local controller = setup()

		controller.server:Connect("Ping", function() end):DoCleaning()

		local before = controller.serverTaskCount()
		for _ = 1, 10 do
			local connectMaid = controller.server:Connect("Ping", function() end)
			connectMaid:DoCleaning()
		end

		expect(controller.serverTaskCount()).toEqual(before)

		controller.destroy()
	end)

	it("tolerates cleaning the same connection twice", function()
		local controller = setup()

		controller.server:Connect("Ping", function() end):DoCleaning()

		local before = controller.serverTaskCount()
		local connectMaid = controller.server:Connect("Ping", function() end)
		connectMaid:DoCleaning()
		connectMaid:DoCleaning()

		expect(controller.serverTaskCount()).toEqual(before)

		controller.destroy()
	end)
end)

describe("Remoting.Bind lifetime", function()
	it("registers a task on the remoting and releases it when the bind is cleaned", function()
		local controller = setup()

		controller.server
			:Bind("Ask", function()
				return true
			end)
			:DoCleaning()

		local before = controller.serverTaskCount()
		local bindMaid = controller.server:Bind("Ask", function()
			return true
		end)

		expect(controller.serverTaskCount()).toEqual(before + 1)

		bindMaid:DoCleaning()

		expect(controller.serverTaskCount()).toEqual(before)

		controller.destroy()
	end)

	it("marks the translated callback dead once the bind is released", function()
		local controller = setup()

		local bindMaid = controller.server:Bind("Ask", function()
			return true
		end)

		expect(controller.settle(controller.client:PromiseInvokeServer("Ask"))).toEqual(true)

		-- Asserted against the translated callback rather than through an invoke: routing the
		-- disconnect error through a BindableFunction gets it logged by the engine even when
		-- the caller pcalls it, which the runner counts as a failed run
		local translated = controller.server:_translateCallback(bindMaid, "Ask", function()
			return true
		end)

		expect(translated()).toEqual(true)

		bindMaid:DoCleaning()

		expect(function()
			translated()
		end).toThrow()

		controller.destroy()
	end)

	it("allows the member to be bound again after release", function()
		local controller = setup()

		local bindMaid = controller.server:Bind("Ask", function()
			return "first"
		end)
		bindMaid:DoCleaning()

		controller.server:Bind("Ask", function()
			return "second"
		end)

		local promise = controller.client:PromiseInvokeServer("Ask")
		expect(controller.settle(promise)).toEqual(true)

		local _isFulfilled, value = promise:Yield()
		expect(value).toEqual("second")

		controller.destroy()
	end)
end)

describe("Remoting promise lifetime", function()
	it("releases the fire task once PromiseFireServer settles", function()
		local controller = setup()

		controller.server:Connect("Ping", function() end)

		local before = controller.clientTaskCount()
		local promise = controller.client:PromiseFireServer("Ping")

		expect(controller.settle(promise)).toEqual(true)
		expect(controller.clientTaskCount()).toEqual(before)

		controller.destroy()
	end)

	it("releases the invoke task once PromiseInvokeServer settles", function()
		local controller = setup()

		controller.server:Bind("Ask", function()
			return true
		end)

		local before = controller.clientTaskCount()
		local promise = controller.client:PromiseInvokeServer("Ask")

		expect(controller.settle(promise)).toEqual(true)
		expect(controller.clientTaskCount()).toEqual(before)

		controller.destroy()
	end)

	it("releases the invoke task once PromiseInvokeClient settles", function()
		local controller = setup()

		controller.client:Bind("AskClient", function()
			return true
		end)

		expect(controller.settle(controller.server:PromiseInvokeClient("AskClient", controller.player))).toEqual(true)

		local before = controller.serverTaskCount()
		local promise = controller.server:PromiseInvokeClient("AskClient", controller.player)

		expect(controller.settle(promise)).toEqual(true)
		expect(controller.serverTaskCount()).toEqual(before)

		controller.destroy()
	end)

	it("does not accumulate tasks across repeated invokes", function()
		local controller = setup()

		controller.server:Bind("Ask", function()
			return true
		end)

		local before = controller.clientTaskCount()
		for _ = 1, 10 do
			expect(controller.settle(controller.client:PromiseInvokeServer("Ask"))).toEqual(true)
		end

		expect(controller.clientTaskCount()).toEqual(before)

		controller.destroy()
	end)
end)

describe("Remoting.BindObservable lifetime", function()
	it("registers a task on the remoting and releases it when the bind is cleaned", function()
		local controller = setup()

		controller.server
			:BindObservable("Stream", function()
				return Observable.new(function()
					return nil
				end)
			end)
			:DoCleaning()

		local before = controller.serverTaskCount()
		local bindMaid = controller.server:BindObservable("Stream", function()
			return Observable.new(function()
				return nil
			end)
		end)

		expect(controller.serverTaskCount() > before).toEqual(true)

		bindMaid:DoCleaning()

		expect(controller.serverTaskCount()).toEqual(before)

		controller.destroy()
	end)

	it("allows the member to be bound again after release", function()
		local controller = setup()

		local bindMaid = controller.server:BindObservable("Stream", function()
			return Observable.new(function(sub)
				sub:Fire("first")
				return nil
			end)
		end)
		bindMaid:DoCleaning()

		controller.server:BindObservable("Stream", function()
			return Observable.new(function(sub)
				sub:Fire("second")
				return nil
			end)
		end)

		local received = {}
		local subscription = controller.client:Observe("Stream"):Subscribe(function(value)
			table.insert(received, value)
		end)

		expect(PromiseTestUtils.awaitValue(function()
			return #received >= 1
		end)).toEqual(true)
		expect(received[#received]).toEqual("second")

		subscription:Destroy()
		controller.destroy()
	end)

	it("keeps one relay per member across repeated observes", function()
		local controller = setup()

		controller.server:BindObservable("Stream", function()
			return Observable.new(function()
				return nil
			end)
		end)

		local first = controller.client:Observe("Stream")
		local relay = controller.client._observableRelays["Stream"]
		local second = controller.client:Observe("Stream")

		expect(controller.client._observableRelays["Stream"]).toBe(relay)
		expect(first).never.toBe(second)

		controller.destroy()
	end)

	it("forgets a client subscription once it is unsubscribed", function()
		local controller = setup()

		controller.server:BindObservable("Stream", function()
			return Observable.new(function(sub)
				sub:Fire(1)
				return nil
			end)
		end)

		local received = {}
		local subscription = controller.client:Observe("Stream"):Subscribe(function(value)
			table.insert(received, value)
		end)

		expect(PromiseTestUtils.awaitValue(function()
			return #received >= 1
		end)).toEqual(true)

		subscription:Destroy()

		local relay = controller.client._observableRelays["Stream"]
		expect(next(relay._subscriptions)).toEqual(nil)

		controller.destroy()
	end)
end)

describe("Remoting.Destroy lifetime", function()
	it("removes every instance it created from the data model", function()
		local controller = setup()

		controller.server:Connect("Ping", function() end)
		controller.server:Bind("Ask", function()
			return true
		end)

		expect(controller.container()).never.toEqual(nil)

		controller.destroyServer()

		expect(controller.container()).toEqual(nil)

		controller.destroy()
	end)

	it("runs the cleanup of a connection that is still live", function()
		local controller = setup()

		local cleaned = false
		local connectMaid = controller.server:Connect("Ping", function() end)
		connectMaid:GiveTask(function()
			cleaned = true
		end)

		controller.destroyServer()

		expect(cleaned).toEqual(true)

		controller.destroy()
	end)

	it("runs the cleanup of a bind that is still live", function()
		local controller = setup()

		local cleaned = false
		local bindMaid = controller.server:Bind("Ask", function()
			return true
		end)
		bindMaid:GiveTask(function()
			cleaned = true
		end)

		controller.destroyServer()

		expect(cleaned).toEqual(true)

		controller.destroy()
	end)

	it("tears down the source of a live observable subscription", function()
		local controller = setup()

		local cleaned = false
		controller.server:BindObservable("Stream", function()
			return Observable.new(function(sub)
				sub:Fire(1)
				return function()
					cleaned = true
				end
			end)
		end)

		local received = {}
		local subscription = controller.client:Observe("Stream"):Subscribe(function(value)
			table.insert(received, value)
		end)

		expect(PromiseTestUtils.awaitValue(function()
			return #received >= 1
		end)).toEqual(true)

		controller.destroyServer()

		expect(cleaned).toEqual(true)

		subscription:Destroy()
		controller.destroy()
	end)

	it("completes a live client subscription when the client is destroyed", function()
		local controller = setup()

		controller.server:BindObservable("Stream", function()
			return Observable.new(function(sub)
				sub:Fire(1)
				return nil
			end)
		end)

		local completed = false
		local subscription = controller.client:Observe("Stream"):Subscribe(nil, nil, function()
			completed = true
		end)

		controller.destroyClient()

		expect(completed).toEqual(true)

		subscription:Destroy()
		controller.destroy()
	end)

	it("empties the remoting maid", function()
		local controller = setup()

		controller.server:Connect("Ping", function() end)
		controller.server:Bind("Ask", function()
			return true
		end)
		controller.server:BindObservable("Stream", function()
			return Observable.new(function()
				return nil
			end)
		end)

		local maid = controller.server._maid
		controller.destroyServer()

		expect(countTasks(maid)).toEqual(0)

		controller.destroy()
	end)
end)
