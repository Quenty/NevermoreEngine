--!nonstrict
--[[
	@class RemotingMember.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local RemotingMember = require("RemotingMember")
local RemotingRealms = require("RemotingRealms")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function newRecordingRemoting()
	local calls = {}
	local fake = setmetatable({}, {
		__index = function(_self, key)
			return function(_selfArg, ...)
				table.insert(calls, {
					method = key,
					args = table.pack(...),
				})
			end
		end,
	})

	return calls, fake
end

describe("RemotingMember.new", function()
	it("stores the remoting, member name, and realm", function()
		local _calls, fake = newRecordingRemoting()
		local member = RemotingMember.new(fake, "Ping", RemotingRealms.CLIENT)

		expect(member.ClassName).toEqual("RemotingMember")
		expect(member._memberName).toEqual("Ping")
		expect(member._remotingRealm).toEqual(RemotingRealms.CLIENT)
	end)

	it("rejects a missing member name", function()
		local _calls, fake = newRecordingRemoting()
		expect(function()
			RemotingMember.new(fake, nil :: any, RemotingRealms.CLIENT)
		end).toThrow()
	end)

	it("rejects a missing realm", function()
		local _calls, fake = newRecordingRemoting()
		expect(function()
			RemotingMember.new(fake, "Ping", nil :: any)
		end).toThrow()
	end)
end)

describe("RemotingMember client-side delegation", function()
	it("forwards FireServer with the member name prefixed", function()
		local calls, fake = newRecordingRemoting()
		local member = RemotingMember.new(fake, "Ping", RemotingRealms.CLIENT)

		member:FireServer("hello", 1)

		expect(#calls).toEqual(1)
		expect(calls[1].method).toEqual("FireServer")
		expect(calls[1].args[1]).toEqual("Ping")
		expect(calls[1].args[2]).toEqual("hello")
		expect(calls[1].args[3]).toEqual(1)
		expect(calls[1].args.n).toEqual(3)
	end)

	it("forwards PromiseFireServer", function()
		local calls, fake = newRecordingRemoting()
		local member = RemotingMember.new(fake, "Ping", RemotingRealms.CLIENT)

		member:PromiseFireServer("payload")

		expect(calls[1].method).toEqual("PromiseFireServer")
		expect(calls[1].args[1]).toEqual("Ping")
		expect(calls[1].args[2]).toEqual("payload")
	end)

	it("forwards InvokeServer", function()
		local calls, fake = newRecordingRemoting()
		local member = RemotingMember.new(fake, "Fetch", RemotingRealms.CLIENT)

		member:InvokeServer(7)

		expect(calls[1].method).toEqual("InvokeServer")
		expect(calls[1].args[1]).toEqual("Fetch")
		expect(calls[1].args[2]).toEqual(7)
	end)

	it("forwards PromiseInvokeServer", function()
		local calls, fake = newRecordingRemoting()
		local member = RemotingMember.new(fake, "Fetch", RemotingRealms.CLIENT)

		member:PromiseInvokeServer()

		expect(calls[1].method).toEqual("PromiseInvokeServer")
		expect(calls[1].args[1]).toEqual("Fetch")
	end)

	it("rejects server-only calls on a client member", function()
		local _calls, fake = newRecordingRemoting()
		local member = RemotingMember.new(fake, "Ping", RemotingRealms.CLIENT)

		expect(function()
			member:FireAllClients()
		end).toThrow()
		expect(function()
			member:InvokeClient()
		end).toThrow()
	end)
end)

describe("RemotingMember server-side delegation", function()
	it("forwards FireAllClients with the member name prefixed", function()
		local calls, fake = newRecordingRemoting()
		local member = RemotingMember.new(fake, "Broadcast", RemotingRealms.SERVER)

		member:FireAllClients("a", "b")

		expect(calls[1].method).toEqual("FireAllClients")
		expect(calls[1].args[1]).toEqual("Broadcast")
		expect(calls[1].args[2]).toEqual("a")
		expect(calls[1].args[3]).toEqual("b")
	end)

	it("forwards FireAllClientsExcept, allowing a nil excluded player", function()
		local calls, fake = newRecordingRemoting()
		local member = RemotingMember.new(fake, "Broadcast", RemotingRealms.SERVER)

		member:FireAllClientsExcept(nil, "payload")

		expect(calls[1].method).toEqual("FireAllClientsExcept")
		expect(calls[1].args[1]).toEqual("Broadcast")
		expect(calls[1].args[2]).toEqual(nil)
		expect(calls[1].args[3]).toEqual("payload")
	end)

	it("forwards DeclareEvent and DeclareMethod", function()
		local calls, fake = newRecordingRemoting()
		local member = RemotingMember.new(fake, "Thing", RemotingRealms.SERVER)

		member:DeclareEvent()
		member:DeclareMethod()

		expect(calls[1].method).toEqual("DeclareEvent")
		expect(calls[1].args[1]).toEqual("Thing")
		expect(calls[2].method).toEqual("DeclareMethod")
		expect(calls[2].args[1]).toEqual("Thing")
	end)

	it("rejects client-only calls on a server member", function()
		local _calls, fake = newRecordingRemoting()
		local member = RemotingMember.new(fake, "Broadcast", RemotingRealms.SERVER)

		expect(function()
			member:FireServer()
		end).toThrow()
		expect(function()
			member:InvokeServer()
		end).toThrow()
	end)

	it("rejects FireClient with a non-player argument", function()
		local _calls, fake = newRecordingRemoting()
		local member = RemotingMember.new(fake, "Broadcast", RemotingRealms.SERVER)

		expect(function()
			member:FireClient(nil :: any)
		end).toThrow()
	end)
end)
