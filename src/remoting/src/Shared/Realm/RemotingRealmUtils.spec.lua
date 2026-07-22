--!strict
--[[
	@class RemotingRealmUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local RemotingRealmUtils = require("RemotingRealmUtils")
local RemotingRealms = require("RemotingRealms")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("RemotingRealmUtils.isRemotingRealm", function()
	it("accepts the SERVER realm", function()
		expect(RemotingRealmUtils.isRemotingRealm(RemotingRealms.SERVER)).toEqual(true)
	end)

	it("accepts the CLIENT realm", function()
		expect(RemotingRealmUtils.isRemotingRealm(RemotingRealms.CLIENT)).toEqual(true)
	end)

	it("rejects arbitrary strings that are not a realm", function()
		expect(RemotingRealmUtils.isRemotingRealm("server-ish")).toEqual(false)
		expect(RemotingRealmUtils.isRemotingRealm("")).toEqual(false)
	end)

	it("rejects nil", function()
		expect(RemotingRealmUtils.isRemotingRealm(nil)).toEqual(false)
	end)

	it("rejects non-string values", function()
		expect(RemotingRealmUtils.isRemotingRealm({})).toEqual(false)
		expect(RemotingRealmUtils.isRemotingRealm(5)).toEqual(false)
		expect(RemotingRealmUtils.isRemotingRealm(true)).toEqual(false)
	end)
end)

describe("RemotingRealmUtils.inferRemotingRealm", function()
	it("infers the SERVER realm when specs run on the server", function()
		-- The test runner executes specs from a server script, so RunService:IsServer()
		-- is true and inference resolves to SERVER.
		expect(RemotingRealmUtils.inferRemotingRealm()).toEqual(RemotingRealms.SERVER)
	end)
end)
