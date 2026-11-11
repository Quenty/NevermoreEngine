--!strict
--[[
	Coverage for BinderGroupProvider: registration before init, the groups-added promise, and
	the custom __index guard that rejects unknown lookups.

	@class BinderGroupProvider.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local BinderGroup = require("BinderGroup")
local BinderGroupProvider = require("BinderGroupProvider")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("BinderGroupProvider.new()", function()
	it("constructs a provider", function()
		local provider = BinderGroupProvider.new(function() end)
		expect((provider :: any).ClassName).toEqual("BinderGroupProvider")
	end)

	it("throws without an init method", function()
		expect(function()
			BinderGroupProvider.new(nil :: any)
		end).toThrow()
	end)
end)

describe("BinderGroupProvider:Init()", function()
	it("runs the init method and resolves the groups-added promise", function()
		local ran = false
		local provider = BinderGroupProvider.new(function(self)
			ran = true
			self:Add("Group", BinderGroup.new({}))
		end)

		expect(provider:PromiseGroupsAdded():IsPending()).toEqual(true)
		provider:Init()

		expect(ran).toEqual(true)
		expect(provider:PromiseGroupsAdded():IsFulfilled()).toEqual(true)
	end)

	it("passes extra Init args to the init method", function()
		local received
		local provider = BinderGroupProvider.new(function(_self, arg)
			received = arg
		end)
		provider:Init(4321)
		expect(received).toEqual(4321)
	end)

	it("throws when initialized twice", function()
		local provider = BinderGroupProvider.new(function() end)
		provider:Init()
		expect(function()
			provider:Init()
		end).toThrow()
	end)
end)

describe("BinderGroupProvider:Add() / Get()", function()
	it("retrieves an added group by name", function()
		local group = BinderGroup.new({})
		local provider = BinderGroupProvider.new(function(self)
			self:Add("MyGroup", group)
		end)
		provider:Init()

		expect(provider:Get("MyGroup")).toEqual(group)
	end)

	it("returns nil for an unknown group name via Get()", function()
		local provider = BinderGroupProvider.new(function() end)
		provider:Init()
		expect(provider:Get("Missing")).toBeNil()
	end)

	it("throws when adding a duplicate group name", function()
		local provider = BinderGroupProvider.new(function(self)
			self:Add("Dup", BinderGroup.new({}))
			self:Add("Dup", BinderGroup.new({}))
		end)

		expect(function()
			provider:Init()
		end).toThrow()
	end)

	it("throws when adding after initialization", function()
		local provider = BinderGroupProvider.new(function() end)
		provider:Init()
		expect(function()
			provider:Add("Late", BinderGroup.new({}))
		end).toThrow()
	end)

	it("throws on a non-string group name", function()
		local provider = BinderGroupProvider.new(function() end)
		expect(function()
			provider:Get(5 :: any)
		end).toThrow()
	end)
end)

describe("BinderGroupProvider __index guard", function()
	it("throws when indexing an unknown key", function()
		local provider = BinderGroupProvider.new(function() end)
		provider:Init()
		expect(function()
			return (provider :: any).SomethingInvalid
		end).toThrow()
	end)
end)
