--!strict
--[[
	@class TieRealmService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")
local TieRealms = require("TieRealms")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local controller = {
		newTieRealmService = function(tieRealm: TieRealms.TieRealm?): any
			local serviceBag = maid:Add(ServiceBag.new())
			local tieRealmService: any = serviceBag:GetService(TieRealmService)
			if tieRealm then
				tieRealmService:SetTieRealm(tieRealm)
			end
			serviceBag:Init()
			return tieRealmService
		end,

		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("TieRealmService.GetTieRealm", function()
	it("returns the realm it was told", function()
		local controller = setup()
		local tieRealmService = controller.newTieRealmService(TieRealms.CLIENT)

		expect(tieRealmService:GetTieRealm()).toBe(TieRealms.CLIENT)

		controller:Destroy()
	end)

	it("infers a realm when it was not told one", function()
		local controller = setup()
		local tieRealmService = controller.newTieRealmService(nil)

		expect(tieRealmService:GetTieRealm()).never.toBeNil()

		controller:Destroy()
	end)
end)

describe("TieRealmService.SetTieRealm", function()
	it("rejects a value that is not a realm", function()
		local controller = setup()
		local tieRealmService = controller.newTieRealmService(nil)

		expect(function()
			tieRealmService:SetTieRealm("bogus")
		end).toThrow("Bad tieRealm")

		controller:Destroy()
	end)
end)

describe("TieRealmService.HasExplicitTieRealm", function()
	it("returns true once a realm was set", function()
		local controller = setup()
		local tieRealmService = controller.newTieRealmService(TieRealms.SERVER)

		expect(tieRealmService:HasExplicitTieRealm()).toBe(true)

		controller:Destroy()
	end)

	it("returns false for an inferred realm", function()
		local controller = setup()
		local tieRealmService = controller.newTieRealmService(nil)

		expect(tieRealmService:HasExplicitTieRealm()).toBe(false)

		controller:Destroy()
	end)
end)
