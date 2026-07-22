--!nonstrict
--[[
	@class Remoting.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")
local Remoting = require("Remoting")
local RemotingRealms = require("RemotingRealms")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function newServerRemoting(name: string, useDummyObject: boolean)
	local instance = Instance.new("Folder")
	local remoting = Remoting.Server.new(instance, name)
	remoting._useDummyObject = useDummyObject
	return remoting, instance
end

local function newDummyRealmPair(name: string)
	local instance = Instance.new("Folder")
	local server = Remoting.Server.new(instance, name)
	server._useDummyObject = true
	local client = Remoting.Client.new(instance, name)
	client._useDummyObject = true
	return server, client, instance
end

-- The designation requires the mock to be in the DataModel; callers clear with
-- PlayerMock.setMockedLocalPlayer(nil) and destroy the mock on the way out.
local function designateLocalPlayerMock(userId: number): Player
	local playerMock = PlayerMock.new({ UserId = userId })
	playerMock.Parent = Workspace
	PlayerMock.setMockedLocalPlayer(playerMock)
	return playerMock
end

describe("Remoting.new", function()
	it("constructs a Remoting and infers the SERVER realm on the server", function()
		local instance = Instance.new("Folder")
		local remoting = Remoting.new(instance, "Test")

		expect(remoting.ClassName).toEqual("Remoting")
		expect(remoting._remotingRealm).toEqual(RemotingRealms.SERVER)
		expect(remoting._name).toEqual("Test")

		remoting:Destroy()
		instance:Destroy()
	end)

	it("rejects a bad instance", function()
		expect(function()
			Remoting.new(nil :: any, "Test")
		end).toThrow()
	end)

	it("rejects a bad name", function()
		local instance = Instance.new("Folder")
		expect(function()
			Remoting.new(instance, nil :: any)
		end).toThrow()
		instance:Destroy()
	end)

	it("rejects a bad realm", function()
		local instance = Instance.new("Folder")
		expect(function()
			Remoting.new(instance, "Test", "not-a-realm" :: any)
		end).toThrow()
		instance:Destroy()
	end)

	it("exposes the realm enum and realm-specific constructors", function()
		expect(Remoting.Realms).toBe(RemotingRealms)

		local instance = Instance.new("Folder")
		local server = Remoting.Server.new(instance, "Test")
		local client = Remoting.Client.new(instance, "Test")

		expect(server._remotingRealm).toEqual(RemotingRealms.SERVER)
		expect(client._remotingRealm).toEqual(RemotingRealms.CLIENT)

		server:Destroy()
		client:Destroy()
		instance:Destroy()
	end)
end)

describe("Remoting naming helpers", function()
	it("suffixes member names with the object type", function()
		local remoting, instance = newServerRemoting("Test", true)

		expect(remoting:_getMemberName("Foo", "Event")).toEqual("FooEvent")
		expect(remoting:_getMemberName("Foo", "Function")).toEqual("FooFunction")

		remoting:Destroy()
		instance:Destroy()
	end)

	it("builds dummy member names only in dummy mode", function()
		local remoting, instance = newServerRemoting("Test", true)

		expect(remoting:_getDummyMemberName("Foo", "OnServerEvent")).toEqual("Foo_OnServerEvent_")

		remoting._useDummyObject = false
		expect(function()
			remoting:_getDummyMemberName("Foo", "OnServerEvent")
		end).toThrow()

		remoting:Destroy()
		instance:Destroy()
	end)

	it("builds a namespaced debug member name", function()
		local remoting, instance = newServerRemoting("MyRemoting", true)

		expect(remoting:_getDebugMemberName("Foo")).toEqual("MyRemoting.Foo")

		remoting:Destroy()
		instance:Destroy()
	end)

	it("uses a Configuration as its container class", function()
		local remoting, instance = newServerRemoting("Test", true)

		expect(remoting:GetContainerClass()).toEqual("Configuration")

		remoting:Destroy()
		instance:Destroy()
	end)
end)

describe("Remoting member access", function()
	it("returns a RemotingMember for an unknown member", function()
		local remoting, instance = newServerRemoting("Test", true)

		local member = remoting.SomeEvent
		expect(member.ClassName).toEqual("RemotingMember")
		expect(member._memberName).toEqual("SomeEvent")

		remoting:Destroy()
		instance:Destroy()
	end)

	it("returns methods and raw fields directly", function()
		local remoting, instance = newServerRemoting("Test", true)

		expect(type(remoting.Connect)).toEqual("function")
		expect(remoting._name).toEqual("Test")

		remoting:Destroy()
		instance:Destroy()
	end)
end)

describe("Remoting server-side object creation (real mode)", function()
	it("creates a Configuration container with a RemoteEvent for a declared event", function()
		local remoting, instance = newServerRemoting("Test", false)

		remoting:DeclareEvent("Foo")

		local container = instance:FindFirstChild("TestRemotes")
		expect(container).never.toBeNil()
		expect(container.ClassName).toEqual("Configuration")
		expect(container.Archivable).toEqual(false)

		local remoteEvent = container:FindFirstChild("FooEvent")
		expect(remoteEvent).never.toBeNil()
		expect(remoteEvent:IsA("RemoteEvent")).toEqual(true)

		remoting:Destroy()
		instance:Destroy()
	end)

	it("creates a RemoteFunction for a declared method", function()
		local remoting, instance = newServerRemoting("Test", false)

		remoting:DeclareMethod("Bar")

		local container = instance:FindFirstChild("TestRemotes")
		local remoteFunction = container:FindFirstChild("BarFunction")
		expect(remoteFunction).never.toBeNil()
		expect(remoteFunction:IsA("RemoteFunction")).toEqual(true)

		remoting:Destroy()
		instance:Destroy()
	end)

	it("reuses the same remote object across calls", function()
		local remoting, instance = newServerRemoting("Test", false)

		local first = remoting:_getOrCreateRemoteEvent("Foo")
		local second = remoting:_getOrCreateRemoteEvent("Foo")
		expect(second).toBe(first)

		remoting:Destroy()
		instance:Destroy()
	end)

	it("does not create a container on the client realm", function()
		local instance = Instance.new("Folder")
		local remoting = Remoting.Client.new(instance, "Test")
		remoting._useDummyObject = false

		remoting:DeclareEvent("Foo")

		expect(instance:FindFirstChild("TestRemotes")).toBeNil()

		remoting:Destroy()
		instance:Destroy()
	end)
end)

describe("Remoting server-side object creation (dummy mode)", function()
	it("creates paired bindable events for a declared event", function()
		local remoting, instance = newServerRemoting("Test", true)

		remoting:DeclareEvent("Foo")

		local container = instance:FindFirstChild("TestRemotes")
		expect(container).never.toBeNil()

		local onClient = container:FindFirstChild("Foo_OnClientEvent_Event")
		local onServer = container:FindFirstChild("Foo_OnServerEvent_Event")
		expect(onClient).never.toBeNil()
		expect(onClient:IsA("BindableEvent")).toEqual(true)
		expect(onServer).never.toBeNil()
		expect(onServer:IsA("BindableEvent")).toEqual(true)

		remoting:Destroy()
		instance:Destroy()
	end)

	it("creates paired bindable functions for a declared method", function()
		local remoting, instance = newServerRemoting("Test", true)

		remoting:DeclareMethod("Bar")

		local container = instance:FindFirstChild("TestRemotes")
		local onServer = container:FindFirstChild("Bar_OnServerInvoke_Function")
		local onClient = container:FindFirstChild("Bar_OnClientInvoke_Function")
		expect(onServer).never.toBeNil()
		expect(onServer:IsA("BindableFunction")).toEqual(true)
		expect(onClient).never.toBeNil()
		expect(onClient:IsA("BindableFunction")).toEqual(true)

		remoting:Destroy()
		instance:Destroy()
	end)
end)

describe("Remoting realm guards", function()
	it("rejects server-side fires on a server remoting", function()
		local remoting, instance = newServerRemoting("Test", true)

		expect(function()
			remoting:FireServer("Foo")
		end).toThrow()
		expect(function()
			remoting:PromiseFireServer("Foo")
		end).toThrow()

		remoting:Destroy()
		instance:Destroy()
	end)

	it("rejects client-side fires on a client remoting", function()
		local instance = Instance.new("Folder")
		local remoting = Remoting.Client.new(instance, "Test")
		remoting._useDummyObject = true

		expect(function()
			remoting:FireAllClients("Foo")
		end).toThrow()

		remoting:Destroy()
		instance:Destroy()
	end)

	it("rejects FireClient without a valid player", function()
		local remoting, instance = newServerRemoting("Test", true)

		expect(function()
			remoting:FireClient("Foo", nil :: any)
		end).toThrow()

		remoting:Destroy()
		instance:Destroy()
	end)
end)

describe("Remoting._translateCallback", function()
	it("passes through plain return values", function()
		local remoting, instance = newServerRemoting("Test", true)
		local maid = Maid.new()

		local wrapped = remoting:_translateCallback(maid, "Foo", function(a, b)
			return a + b, "extra"
		end)

		local sum, extra = wrapped(2, 3)
		expect(sum).toEqual(5)
		expect(extra).toEqual("extra")

		maid:DoCleaning()
		remoting:Destroy()
		instance:Destroy()
	end)

	it("errors once the owning maid has been cleaned up", function()
		local remoting, instance = newServerRemoting("Test", true)
		local maid = Maid.new()

		local wrapped = remoting:_translateCallback(maid, "Foo", function()
			return true
		end)

		maid:DoCleaning()

		expect(function()
			wrapped()
		end).toThrow()

		remoting:Destroy()
		instance:Destroy()
	end)

	it("unwraps a promise returned by the callback", function()
		local remoting, instance = newServerRemoting("Test", true)
		local maid = Maid.new()

		local wrapped = remoting:_translateCallback(maid, "Foo", function()
			return Promise.resolved(42)
		end)

		expect(wrapped()).toEqual(42)

		maid:DoCleaning()
		remoting:Destroy()
		instance:Destroy()
	end)
end)

describe("Remoting dummy-mode round trip", function()
	it("delivers a client FireServer to a server Connect handler", function()
		local instance = Instance.new("Folder")
		local server = Remoting.Server.new(instance, "RoundTrip")
		server._useDummyObject = true
		local client = Remoting.Client.new(instance, "RoundTrip")
		client._useDummyObject = true

		local received
		server:Connect("Ping", function(_player, value)
			received = value
		end)

		client:FireServer("Ping", 42)

		expect(PromiseTestUtils.awaitValue(function()
			return received ~= nil
		end)).toEqual(true)
		expect(received).toEqual(42)

		server:Destroy()
		client:Destroy()
		instance:Destroy()
	end)

	it("attributes a client FireServer to the designated mocked local player", function()
		local server, client, instance = newDummyRealmPair("RoundTrip")
		local playerMock = designateLocalPlayerMock(12345)

		local receivedPlayer
		server:Connect("Ping", function(player)
			receivedPlayer = player
		end)

		client:FireServer("Ping")

		expect(PromiseTestUtils.awaitValue(function()
			return receivedPlayer ~= nil
		end)).toEqual(true)
		expect(receivedPlayer).toBe(playerMock)

		PlayerMock.setMockedLocalPlayer(nil)
		server:Destroy()
		client:Destroy()
		playerMock:Destroy()
		instance:Destroy()
	end)

	it("delivers a server FireClient targeted at the mocked local player to the client Connect handler", function()
		local server, client, instance = newDummyRealmPair("RoundTrip")
		local playerMock = designateLocalPlayerMock(12345)

		-- Declare first so the client's Connect binds synchronously to the existing channel.
		server:DeclareEvent("Pong")

		local received
		client:Connect("Pong", function(value)
			received = value
		end)

		server:FireClient("Pong", playerMock, 42)

		expect(PromiseTestUtils.awaitValue(function()
			return received ~= nil
		end)).toEqual(true)
		expect(received).toEqual(42)

		PlayerMock.setMockedLocalPlayer(nil)
		server:Destroy()
		client:Destroy()
		playerMock:Destroy()
		instance:Destroy()
	end)

	it("drops a server FireClient targeted at a player who is not the mocked local player", function()
		local server, client, instance = newDummyRealmPair("RoundTrip")
		local playerMock = designateLocalPlayerMock(12345)
		local otherPlayerMock = PlayerMock.new({ UserId = 12346 })

		server:DeclareEvent("Pong")

		local receivedTags = {}
		client:Connect("Pong", function(tag)
			table.insert(receivedTags, tag)
		end)

		-- Ordered probe: if the drop leaked, "dropped" would arrive before "delivered".
		server:FireClient("Pong", otherPlayerMock, "dropped")
		server:FireClient("Pong", playerMock, "delivered")

		expect(PromiseTestUtils.awaitValue(function()
			return #receivedTags >= 1
		end)).toEqual(true)
		expect(receivedTags).toEqual({ "delivered" })

		PlayerMock.setMockedLocalPlayer(nil)
		server:Destroy()
		client:Destroy()
		playerMock:Destroy()
		otherPlayerMock:Destroy()
		instance:Destroy()
	end)

	it("multi-casts a server FireAllClients to every client-realm Connect handler", function()
		local server, clientA, instance = newDummyRealmPair("RoundTrip")
		local clientB = Remoting.Client.new(instance, "RoundTrip")
		clientB._useDummyObject = true

		server:DeclareEvent("Pong")

		local receivedA, receivedB
		clientA:Connect("Pong", function(value)
			receivedA = value
		end)
		clientB:Connect("Pong", function(value)
			receivedB = value
		end)

		server:FireAllClients("Pong", 42)

		expect(PromiseTestUtils.awaitValue(function()
			return receivedA ~= nil and receivedB ~= nil
		end)).toEqual(true)
		expect(receivedA).toEqual(42)
		expect(receivedB).toEqual(42)

		server:Destroy()
		clientA:Destroy()
		clientB:Destroy()
		instance:Destroy()
	end)

	it("FireAllClientsExcept skips the mocked local player and delivers for other or nil exclusions", function()
		local server, client, instance = newDummyRealmPair("RoundTrip")
		local playerMock = designateLocalPlayerMock(12345)
		local otherPlayerMock = PlayerMock.new({ UserId = 12346 })

		server:DeclareEvent("Pong")

		local receivedTags = {}
		client:Connect("Pong", function(tag)
			table.insert(receivedTags, tag)
		end)

		-- Ordered probe: a leaked "skipped" would arrive first.
		server:FireAllClientsExcept("Pong", playerMock, "skipped")
		server:FireAllClientsExcept("Pong", otherPlayerMock, "delivered")
		server:FireAllClientsExcept("Pong", nil, "broadcast")

		expect(PromiseTestUtils.awaitValue(function()
			return #receivedTags >= 2
		end)).toEqual(true)
		expect(receivedTags).toEqual({ "delivered", "broadcast" })

		PlayerMock.setMockedLocalPlayer(nil)
		server:Destroy()
		client:Destroy()
		playerMock:Destroy()
		otherPlayerMock:Destroy()
		instance:Destroy()
	end)

	it("returns a client Bind result to a server PromiseInvokeClient against a mock player", function()
		local server, client, instance = newDummyRealmPair("RoundTrip")
		local playerMock = designateLocalPlayerMock(12345)

		-- Declare first so the client's Bind attaches synchronously to the existing channel.
		server:DeclareMethod("Compute")
		client:Bind("Compute", function(n)
			return n * 2
		end)

		local promise = server:PromiseInvokeClient("Compute", playerMock, 5)
		expect(PromiseTestUtils.awaitSettled(promise)).toEqual(true)

		local isFulfilled, result = promise:Yield()
		expect(isFulfilled).toEqual(true)
		expect(result).toEqual(10)

		PlayerMock.setMockedLocalPlayer(nil)
		server:Destroy()
		client:Destroy()
		playerMock:Destroy()
		instance:Destroy()
	end)

	it("InvokeClient returns the client's bound value", function()
		local server, client, instance = newDummyRealmPair("RoundTrip")
		local playerMock = designateLocalPlayerMock(12345)

		server:DeclareMethod("Compute")
		client:Bind("Compute", function(n)
			return n * 2
		end)

		local result
		task.spawn(function()
			result = server:InvokeClient("Compute", playerMock, 5)
		end)

		expect(PromiseTestUtils.awaitValue(function()
			return result ~= nil
		end)).toEqual(true)
		expect(result).toEqual(10)

		PlayerMock.setMockedLocalPlayer(nil)
		server:Destroy()
		client:Destroy()
		playerMock:Destroy()
		instance:Destroy()
	end)

	it("supports PlayerMocks through the RemotingMember API", function()
		local server, client, instance = newDummyRealmPair("RoundTrip")
		local playerMock = designateLocalPlayerMock(12345)

		server.Pong:DeclareEvent()

		local received
		client.Pong:Connect(function(value)
			received = value
		end)

		server.Pong:FireClient(playerMock, 42)

		expect(PromiseTestUtils.awaitValue(function()
			return received ~= nil
		end)).toEqual(true)
		expect(received).toEqual(42)

		PlayerMock.setMockedLocalPlayer(nil)
		server:Destroy()
		client:Destroy()
		playerMock:Destroy()
		instance:Destroy()
	end)

	it("rejects a plain Instance that is neither a Player nor a PlayerMock", function()
		local server, client, instance = newDummyRealmPair("RoundTrip")
		local folder = Instance.new("Folder")

		expect(function()
			server:FireClient("Pong", folder)
		end).toThrow()
		expect(function()
			server:PromiseInvokeClient("Compute", folder)
		end).toThrow()
		expect(function()
			server:FireAllClientsExcept("Pong", folder)
		end).toThrow()
		expect(function()
			server.Pong:FireClient(folder)
		end).toThrow()

		folder:Destroy()
		server:Destroy()
		client:Destroy()
		instance:Destroy()
	end)

	it("returns a bound server value to a client InvokeServer", function()
		local instance = Instance.new("Folder")
		local server = Remoting.Server.new(instance, "RoundTrip")
		server._useDummyObject = true
		local client = Remoting.Client.new(instance, "RoundTrip")
		client._useDummyObject = true

		server:Bind("Double", function(_player, n)
			return n * 2
		end)

		local promise = client:PromiseInvokeServer("Double", 5)
		expect(PromiseTestUtils.awaitSettled(promise)).toEqual(true)

		local isFulfilled, result = promise:Yield()
		expect(isFulfilled).toEqual(true)
		expect(result).toEqual(10)

		server:Destroy()
		client:Destroy()
		instance:Destroy()
	end)
end)

describe("Remoting.Destroy", function()
	it("cleans up created remote instances and clears the metatable", function()
		local remoting, instance = newServerRemoting("Test", false)

		remoting:DeclareEvent("Foo")
		local container = remoting._container
		expect(container).never.toBeNil()
		expect(container.Parent).toEqual(instance)

		remoting:Destroy()

		expect(container.Parent).toEqual(nil)
		expect(getmetatable(remoting)).toEqual(nil)

		instance:Destroy()
	end)
end)
