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
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")
local WellKnownAccessFeatureNames = require("WellKnownAccessFeatureNames")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local accessDataService: AccessDataService.AccessDataService = serviceBag:GetService(AccessDataService) :: any
	serviceBag:Init()
	serviceBag:Start()

	local controller = {
		maid = maid,
		accessDataService = accessDataService,
		fakePlayer = function(): Player
			return maid:Add(PlayerMock.new()) :: any
		end,
		registerAllowed = function(featureName: string, allowed: boolean)
			maid:GiveTask(accessDataService:RegisterFact(maid:Add(AccessFact.new(`{featureName}Fact`, {
				resolve = function()
					return allowed
				end,
			}))))
			maid:GiveTask(
				accessDataService:RegisterFeature(maid:Add(AccessFeature.anyOf(featureName, { `{featureName}Fact` })))
			)
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
		-- The point of the tie: a package that gates on access should not have to depend on this one.
		local controller = setup()

		expect(AccessDataServiceInterface:HasImplementation(ReplicatedStorage)).toEqual(true)

		controller:Destroy()
	end)

	it("answers by name through the tie", function()
		-- Asserted against the shipped feature rather than one this test registers: the tie is implemented
		-- on ReplicatedStorage, so in a shared test place Find may resolve another live bag's service.
		-- Every bag has the built-ins, so this holds whichever one answers.
		local controller = setup()

		local tie = assert(AccessDataServiceInterface:Find(ReplicatedStorage), "No implementation")
		expect(type(tie:IsFeatureAllowedByName(controller.fakePlayer(), WellKnownAccessFeatureNames.OWNS_GAME))).toEqual(
			"boolean"
		)

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
		-- Guards the trap that every access observable opens on unresolved: a reader that keeps the first
		-- emission instead of the last reports "denied" for everything, and every false-expecting test
		-- still passes.
		local controller = setup()
		controller.registerAllowed("chapters", true)

		expect(controller.accessDataService:IsFeatureAllowedByName(controller.fakePlayer(), "chapters")).toEqual(true)

		controller:Destroy()
	end)

	it("reads a denial as not allowed", function()
		local controller = setup()
		controller.registerAllowed("chapters", false)

		expect(controller.accessDataService:IsFeatureAllowedByName(controller.fakePlayer(), "chapters")).toEqual(false)

		controller:Destroy()
	end)

	it("fails closed on unresolved, since a boolean cannot carry a third answer", function()
		local controller = setup()
		controller.maid:GiveTask(
			controller.accessDataService:RegisterFact(controller.maid:Add(AccessFact.new("pending", {
				resolve = function()
					return nil
				end,
			})))
		)
		controller.maid:GiveTask(
			controller.accessDataService:RegisterFeature(
				controller.maid:Add(AccessFeature.anyOf("chapters", { "pending" }))
			)
		)

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
		controller.registerAllowed("chapters", false)

		local player = controller.fakePlayer()
		local last = nil
		controller.maid:GiveTask(
			controller.accessDataService:ObserveIsFeatureAllowedByName(player, "chapters"):Subscribe(function(value)
				last = value
			end)
		)

		expect(last).toEqual(false)

		controller.accessDataService:SetFactOverride(player, "chaptersFact", true)
		expect(last).toEqual(true)

		controller:Destroy()
	end)
end)
