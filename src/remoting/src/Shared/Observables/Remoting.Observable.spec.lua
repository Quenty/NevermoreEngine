--!nonstrict
--[[
	@class RemotingObservable.spec.lua
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

local function setup()
	local instance = Instance.new("Folder")

	local server = Remoting.Server.new(instance, "ObservableTest")
	server._useDummyObject = true

	local client = Remoting.Client.new(instance, "ObservableTest")
	client._useDummyObject = true

	local playerMock = PlayerMock.new({ UserId = 12345 })
	playerMock.Parent = Workspace
	PlayerMock.setMockedLocalPlayer(playerMock)

	local serverDestroyed = false

	local controller = {}

	controller.server = server
	controller.client = client
	controller.player = playerMock

	function controller.destroyServer()
		serverDestroyed = true
		server:Destroy()
	end

	function controller.awaitCount(getCount, target)
		return PromiseTestUtils.awaitValue(function()
			return getCount() >= target
		end)
	end

	function controller.destroy()
		client:Destroy()
		if not serverDestroyed then
			server:Destroy()
		end
		PlayerMock.setMockedLocalPlayer(nil)
		playerMock:Destroy()
		instance:Destroy()
	end

	return controller
end

describe("Remoting.BindObservable", function()
	it("delivers emissions from the server source to the client", function()
		local controller = setup()

		controller.server:BindObservable("Health", function()
			return Observable.new(function(sub)
				sub:Fire(10)
				sub:Fire(20)
				return nil
			end)
		end)

		local received = {}
		local subscription = controller.client:Observe("Health"):Subscribe(function(value)
			table.insert(received, value)
		end)

		expect(controller.awaitCount(function()
			return #received
		end, 2)).toEqual(true)
		expect(received).toEqual({ 10, 20 })

		subscription:Destroy()
		controller.destroy()
	end)

	it("passes the requesting player and the client arguments to the factory", function()
		local controller = setup()

		local receivedPlayer, receivedArgs
		controller.server:BindObservable("Health", function(player, ...)
			receivedPlayer = player
			receivedArgs = table.pack(...)

			return Observable.new(function(sub)
				sub:Fire(true)
				return nil
			end)
		end)

		local received = {}
		local subscription = controller.client:Observe("Health", "entity", 7):Subscribe(function(value)
			table.insert(received, value)
		end)

		expect(controller.awaitCount(function()
			return #received
		end, 1)).toEqual(true)
		expect(receivedPlayer).toBe(controller.player)
		expect(receivedArgs.n).toEqual(2)
		expect(receivedArgs[1]).toEqual("entity")
		expect(receivedArgs[2]).toEqual(7)

		subscription:Destroy()
		controller.destroy()
	end)

	it("subscribes once the member is bound after the client is already observing", function()
		local controller = setup()

		local received = {}
		local subscription = controller.client:Observe("Late"):Subscribe(function(value)
			table.insert(received, value)
		end)

		controller.server:BindObservable("Late", function()
			return Observable.new(function(sub)
				sub:Fire("ready")
				return nil
			end)
		end)

		expect(controller.awaitCount(function()
			return #received
		end, 1)).toEqual(true)
		expect(received).toEqual({ "ready" })

		subscription:Destroy()
		controller.destroy()
	end)

	it("completes the client subscription when the server source completes", function()
		local controller = setup()

		controller.server:BindObservable("Health", function()
			return Observable.new(function(sub)
				sub:Fire(1)
				sub:Complete()
				return nil
			end)
		end)

		local completed = false
		local subscription = controller.client:Observe("Health"):Subscribe(nil, nil, function()
			completed = true
		end)

		expect(PromiseTestUtils.awaitValue(function()
			return completed
		end)).toEqual(true)

		subscription:Destroy()
		controller.destroy()
	end)

	it("fails the client subscription when the server source fails", function()
		local controller = setup()

		controller.server:BindObservable("Health", function()
			return Observable.new(function(sub)
				sub:Fail("bad news")
				return nil
			end)
		end)

		local failure
		local subscription = controller.client:Observe("Health"):Subscribe(nil, function(err)
			failure = err
		end)

		expect(PromiseTestUtils.awaitValue(function()
			return failure ~= nil
		end)).toEqual(true)
		expect(failure).toEqual("bad news")

		subscription:Destroy()
		controller.destroy()
	end)

	it("fails the client subscription when the factory does not return an observable", function()
		local controller = setup()

		controller.server:BindObservable("Health", function()
			return nil
		end)

		local failure
		local subscription = controller.client:Observe("Health"):Subscribe(nil, function(err)
			failure = err
		end)

		expect(PromiseTestUtils.awaitValue(function()
			return failure ~= nil
		end)).toEqual(true)

		subscription:Destroy()
		controller.destroy()
	end)

	it("tears down the server source when the client unsubscribes", function()
		local controller = setup()

		local cleanedUp = false
		controller.server:BindObservable("Health", function()
			return Observable.new(function(sub)
				sub:Fire(1)
				return function()
					cleanedUp = true
				end
			end)
		end)

		local received = {}
		local subscription = controller.client:Observe("Health"):Subscribe(function(value)
			table.insert(received, value)
		end)

		expect(controller.awaitCount(function()
			return #received
		end, 1)).toEqual(true)

		subscription:Destroy()

		expect(PromiseTestUtils.awaitValue(function()
			return cleanedUp
		end)).toEqual(true)

		controller.destroy()
	end)

	it("opens a separate server stream for each subscription", function()
		local controller = setup()

		local factoryCalls = 0
		controller.server:BindObservable("Health", function()
			factoryCalls += 1

			return Observable.new(function(sub)
				sub:Fire(factoryCalls)
				return nil
			end)
		end)

		local observable = controller.client:Observe("Health")

		local firstReceived = {}
		local first = observable:Subscribe(function(value)
			table.insert(firstReceived, value)
		end)

		local secondReceived = {}
		local second = observable:Subscribe(function(value)
			table.insert(secondReceived, value)
		end)

		expect(controller.awaitCount(function()
			return #firstReceived
		end, 1)).toEqual(true)
		expect(controller.awaitCount(function()
			return #secondReceived
		end, 1)).toEqual(true)
		expect(factoryCalls).toEqual(2)

		first:Destroy()
		second:Destroy()
		controller.destroy()
	end)

	it("completes live client subscriptions when the server remoting is destroyed", function()
		local controller = setup()

		controller.server:BindObservable("Health", function()
			return Observable.new(function(sub)
				sub:Fire(1)
				return nil
			end)
		end)

		local received = {}
		local completed = false
		local subscription = controller.client:Observe("Health"):Subscribe(
			function(value)
				table.insert(received, value)
			end,
			nil,
			function()
				completed = true
			end
		)

		expect(controller.awaitCount(function()
			return #received
		end, 1)).toEqual(true)

		controller.destroyServer()

		expect(PromiseTestUtils.awaitValue(function()
			return completed
		end)).toEqual(true)

		subscription:Destroy()
		controller.destroy()
	end)

	it("drops the server subscription when the bind is released", function()
		local controller = setup()

		local cleanedUp = false
		local bindMaid = controller.server:BindObservable("Health", function()
			return Observable.new(function(sub)
				sub:Fire(1)
				return function()
					cleanedUp = true
				end
			end)
		end)

		local received = {}
		local subscription = controller.client:Observe("Health"):Subscribe(function(value)
			table.insert(received, value)
		end)

		expect(controller.awaitCount(function()
			return #received
		end, 1)).toEqual(true)

		bindMaid:DoCleaning()

		expect(PromiseTestUtils.awaitValue(function()
			return cleanedUp
		end)).toEqual(true)

		subscription:Destroy()
		controller.destroy()
	end)
end)

describe("Remoting observable guards", function()
	it("rejects Observe on the server", function()
		local controller = setup()

		expect(function()
			controller.server:Observe("Health")
		end).toThrow()

		controller.destroy()
	end)

	it("rejects BindObservable on the client", function()
		local controller = setup()

		expect(function()
			controller.client:BindObservable("Health", function()
				return Observable.new(function()
					return nil
				end)
			end)
		end).toThrow()

		controller.destroy()
	end)

	it("rejects binding a member as both a method and an observable", function()
		local controller = setup()

		controller.server:Bind("Mixed", function()
			return true
		end)

		expect(function()
			controller.server:BindObservable("Mixed", function()
				return Observable.new(function()
					return nil
				end)
			end)
		end).toThrow()

		controller.destroy()
	end)

	it("rejects binding a member as both an observable and a method", function()
		local controller = setup()

		controller.server:BindObservable("Mixed", function()
			return Observable.new(function()
				return nil
			end)
		end)

		expect(function()
			controller.server:Bind("Mixed", function()
				return true
			end)
		end).toThrow()

		controller.destroy()
	end)

	it("rejects binding the same observable member twice", function()
		local controller = setup()

		local factory = function()
			return Observable.new(function()
				return nil
			end)
		end

		controller.server:BindObservable("Health", factory)

		expect(function()
			controller.server:BindObservable("Health", factory)
		end).toThrow()

		controller.destroy()
	end)
end)
