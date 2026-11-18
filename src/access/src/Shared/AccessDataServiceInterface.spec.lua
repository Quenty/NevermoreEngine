--!strict
--[[
	@class AccessDataServiceInterface.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessDataService = require("AccessDataService")
local AccessDataServiceInterface = require("AccessDataServiceInterface")
local AccessFact = require("AccessFact")
local AccessFeature = require("AccessFeature")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")
local WellKnownAccessFeatureNames = require("WellKnownAccessFeatureNames")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	maid: Maid.Maid,
	accessDataService: AccessDataService.AccessDataService,
	fakePlayer: () -> Player,
	registerFeature: (featureName: string, allowed: boolean?) -> (),
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local serviceBag = maid:Add(ServiceBag.new())
	local accessDataService: AccessDataService.AccessDataService = serviceBag:GetService(AccessDataService) :: any
	serviceBag:Init()
	serviceBag:Start()

	local controller: Controller = {
		maid = maid,
		accessDataService = accessDataService,
		fakePlayer = function()
			return maid:Add(PlayerMock.new()) :: any
		end,
		registerFeature = function(featureName, allowed)
			local factName = `{featureName}Fact`
			maid:GiveTask(accessDataService:RegisterFact(maid:Add(AccessFact.new(factName, {
				resolve = function()
					return allowed
				end,
			}))))
			maid:GiveTask(accessDataService:RegisterFeature(maid:Add(AccessFeature.anyOf(featureName, { factName }))))
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("AccessDataServiceInterface", function()
	it("is findable without requiring the service", function()
		local controller = setup()

		expect(AccessDataServiceInterface:HasImplementation(ReplicatedStorage)).toEqual(true)

		controller:Destroy()
	end)

	it("answers by name through the tie", function()
		local controller = setup()

		local tie = assert(AccessDataServiceInterface:Find(ReplicatedStorage), "No implementation")
		local allowed = tie:IsFeatureAllowedByName(controller.fakePlayer(), WellKnownAccessFeatureNames.OWNS_GAME)

		expect(type(allowed)).toEqual("boolean")

		controller:Destroy()
	end)

	it("lists what is registered through the tie", function()
		local controller = setup()

		local tie = assert(AccessDataServiceInterface:Find(ReplicatedStorage), "No implementation")

		expect(tie:HasFeature(WellKnownAccessFeatureNames.OWNS_GAME)).toEqual(true)
		expect(tie:HasFeature("nosuch")).toEqual(false)

		controller:Destroy()
	end)
end)

describe("AccessDataService.IsFeatureAllowedByName", function()
	it("reads a granted feature as allowed", function()
		local controller = setup()
		controller.registerFeature("chapters", true)

		expect(controller.accessDataService:IsFeatureAllowedByName(controller.fakePlayer(), "chapters")).toEqual(true)

		controller:Destroy()
	end)

	it("reads a denial as not allowed", function()
		local controller = setup()
		controller.registerFeature("chapters", false)

		expect(controller.accessDataService:IsFeatureAllowedByName(controller.fakePlayer(), "chapters")).toEqual(false)

		controller:Destroy()
	end)

	it("fails closed on unresolved, since a boolean cannot carry a third answer", function()
		local controller = setup()
		controller.registerFeature("chapters", nil)

		expect(controller.accessDataService:IsFeatureAllowedByName(controller.fakePlayer(), "chapters")).toEqual(false)

		controller:Destroy()
	end)

	it("refuses a feature nobody registered, so a typo is loud", function()
		local controller = setup()

		expect(function()
			controller.accessDataService:IsFeatureAllowedByName(controller.fakePlayer(), "chpaters")
		end).toThrow("No feature registered")

		controller:Destroy()
	end)
end)

describe("AccessDataService.ObserveIsFeatureAllowedByName", function()
	it("tracks the verdict as it changes", function()
		local controller = setup()
		controller.registerFeature("chapters", false)

		local player = controller.fakePlayer()
		local allowed = controller.maid:Add(
			ObservableSpy.new(controller.accessDataService:ObserveIsFeatureAllowedByName(player, "chapters"))
		)

		expect(allowed:GetLastValue()).toEqual(false)

		controller.accessDataService:SetFactOverride(player, "chaptersFact", true)
		expect(allowed:GetLastValue()).toEqual(true)

		controller:Destroy()
	end)
end)
