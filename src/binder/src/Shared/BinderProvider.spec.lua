--[[
	@class BinderProvider.spec.lua
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("BinderProvider.new()", function()
	local provider
	local initialized = false

	it("should execute immediately", function()
		provider = BinderProvider.new("BinderServiceName", function(self, arg)
			initialized = true
			assert(arg == 12345, "Bad arg")

			self:Add(Binder.new("Test", function()
				return { Destroy = function() end }
			end))
		end)

		expect(provider).toEqual(expect.any("table"))
	end)

	it("should initialize", function()
		expect(initialized).toEqual(false)
		provider:Init(12345)
		expect(initialized).toEqual(true)
	end)

	it("should contain the binder", function()
		expect(provider.Test).toEqual(expect.any("table"))
	end)

	if provider then
		provider:Destroy()
	end
end)
