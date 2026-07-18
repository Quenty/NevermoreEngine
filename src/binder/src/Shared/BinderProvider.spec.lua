--!nonstrict
--[[
	@class BinderProvider.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("BinderProvider.new()", function()
	it("should construct a provider", function()
		local provider = BinderProvider.new("BinderServiceName", function(_self) end)
		expect(provider).toEqual(expect.any("table"))
		provider:Destroy()
	end)

	it("should initialize and call the init callback", function()
		local initialized = false

		local provider = BinderProvider.new("BinderServiceName", function(_self, arg)
			initialized = true
			assert(arg == 12345, "Bad arg")
		end)

		expect(initialized).toEqual(false)
		provider:Init(12345)
		expect(initialized).toEqual(true)

		provider:Destroy()
	end)

	it("should contain the binder after init", function()
		local binder

		local provider = BinderProvider.new("BinderServiceName", function(self)
			binder = Binder.new("Test", function()
				return { Destroy = function() end }
			end)
			self:Add(binder)
		end)

		provider:Init()

		expect(provider.Test).toEqual(expect.any("table"))

		provider:Destroy()
		if binder then
			binder:Destroy()
		end
	end)
end)
