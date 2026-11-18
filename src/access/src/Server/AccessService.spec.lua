--!strict
--[[
	@class AccessService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessDataService = require("AccessDataService")
local AccessFeature = require("AccessFeature")
local AccessService = require("AccessService")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local WellKnownAccessFeatureNames = require("WellKnownAccessFeatureNames")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	maid: Maid.Maid,
	serviceBag: ServiceBag.ServiceBag,
	accessService: AccessService.AccessService,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())

	local controller: Controller = {
		maid = maid,
		serviceBag = serviceBag,
		accessService = serviceBag:GetService(AccessService) :: any,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("AccessService", function()
	it("initializes and starts, command service and all", function()
		local controller = setup()

		expect(function()
			controller.serviceBag:Init()
			controller.serviceBag:Start()
		end).never.toThrow()

		controller:Destroy()
	end)

	it("hands back the same registry the shared service exposes", function()
		local controller = setup()
		local direct = controller.serviceBag:GetService(AccessDataService)
		controller.serviceBag:Init()

		expect(controller.accessService:GetAccessDataService()).toBe(direct)

		controller:Destroy()
	end)

	it("registers features that are then readable through the entry point", function()
		local controller = setup()
		controller.serviceBag:Init()

		local accessDataService = controller.accessService:GetAccessDataService()
		controller.maid:GiveTask(
			accessDataService:RegisterFeature(controller.maid:Add(AccessFeature.alwaysAllowed("hub")))
		)

		expect(accessDataService:GetFeatureNames()).toEqual({ "hub", WellKnownAccessFeatureNames.OWNS_GAME })

		controller:Destroy()
	end)
end)
