--!strict
--[[
	Boots the server entry point the way a game does. The test place's ServerMain returns before it builds
	a ServiceBag when it is running tests, so without this the wiring in Init is never executed anywhere --
	and "the package fails to start once you pull in Cmdr" is exactly the kind of break that should not
	wait for a game to find it.

	@class AccessService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessDataService = require("AccessDataService")
local AccessFeature = require("AccessFeature")
local AccessService = require("AccessService")
local Jest = require("Jest")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local WellKnownAccessFeatureNames = require("WellKnownAccessFeatureNames")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local accessService = serviceBag:GetService(AccessService) :: any

	return {
		maid = maid,
		serviceBag = serviceBag,
		accessService = accessService,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}
end

describe("AccessService", function()
	it("initializes and starts, command service and all", function()
		local controller = setup()

		expect(function()
			controller.serviceBag:Init()
			controller.serviceBag:Start()
		end).never.toThrow()

		controller:destroy()
	end)

	it("hands back the same registry the shared service exposes", function()
		-- A game registers through the entry point; anything reading AccessDataService directly has to be
		-- looking at the same registry or half the game gates on an empty one.
		local controller = setup()
		local direct = controller.serviceBag:GetService(AccessDataService)
		controller.serviceBag:Init()

		expect(controller.accessService:GetAccessDataService()).toBe(direct)

		controller:destroy()
	end)

	it("registers features that are then readable through the entry point", function()
		local controller = setup()
		controller.serviceBag:Init()

		local accessDataService = controller.accessService:GetAccessDataService()
		accessDataService:RegisterFeature(controller.maid:Add(AccessFeature.alwaysAllowed("hub")))

		expect(accessDataService:GetFeatureNames()).toEqual({ "hub", WellKnownAccessFeatureNames.OWNS_GAME })

		controller:destroy()
	end)
end)
