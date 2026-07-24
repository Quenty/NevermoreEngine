--!strict
--[[
	@class GenericScreenGuiProvider.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local GenericScreenGuiProvider = require("GenericScreenGuiProvider")
local Jest = require("Jest")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(orders: { [string]: number })
	local serviceBag = ServiceBag.new()
	local provider = serviceBag:GetService(GenericScreenGuiProvider.new(orders))
	serviceBag:Init()
	serviceBag:Start()

	return serviceBag, provider :: any
end

describe("GenericScreenGuiProvider.GetDisplayOrder", function()
	it("returns the registered order", function()
		local serviceBag, provider = setup({ FOO = 5 })

		expect(provider:GetDisplayOrder("FOO")).toBe(5)

		serviceBag:Destroy()
	end)

	it("returns each registered order independently", function()
		local serviceBag, provider = setup({ FOO = 5, BAR = 12 })

		expect(provider:GetDisplayOrder("FOO")).toBe(5)
		expect(provider:GetDisplayOrder("BAR")).toBe(12)

		serviceBag:Destroy()
	end)

	it("errors on an unregistered order name", function()
		local serviceBag, provider = setup({ FOO = 5 })

		expect(function()
			provider:GetDisplayOrder("NOPE")
		end).toThrow()

		serviceBag:Destroy()
	end)

	it("falls back to the registered default after the order ValueObjects are torn down", function()
		local serviceBag, provider = setup({ FOO = 5 })
		serviceBag:Destroy()

		expect(provider:GetDisplayOrder("FOO")).toBe(5)
	end)
end)

describe("GenericScreenGuiProvider.Get", function()
	it("returns a ScreenGui carrying the registered display order (headless)", function()
		local serviceBag, provider = setup({ FOO = 7 })

		local screenGui = provider:Get("FOO")
		expect(screenGui:IsA("ScreenGui")).toBe(true)
		expect(screenGui.DisplayOrder).toBe(7)

		screenGui:Destroy()
		serviceBag:Destroy()
	end)

	it("still returns a ScreenGui at the default order after teardown instead of crashing", function()
		local serviceBag, provider = setup({ FOO = 7 })
		serviceBag:Destroy()

		local screenGui = provider:Get("FOO")
		expect(screenGui:IsA("ScreenGui")).toBe(true)
		expect(screenGui.DisplayOrder).toBe(7)

		screenGui:Destroy()
	end)

	it("errors on an unregistered order name", function()
		local serviceBag, provider = setup({ FOO = 7 })

		expect(function()
			provider:Get("NOPE")
		end).toThrow()

		serviceBag:Destroy()
	end)
end)

describe("GenericScreenGuiProvider.ObserveDisplayOrder", function()
	it("emits the current display order on subscription", function()
		local serviceBag, provider = setup({ FOO = 5 })
		local maid = Maid.new()

		local observed: number? = nil
		maid:GiveTask(provider:ObserveDisplayOrder("FOO"):Subscribe(function(value: number)
			observed = value
		end))

		expect(observed).toBe(5)

		maid:DoCleaning()
		serviceBag:Destroy()
	end)
end)
