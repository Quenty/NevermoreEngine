--!strict
--[[
	@class AccessPlayer.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessDataService = require("AccessDataService")
local AccessFact = require("AccessFact")
local AccessFeature = require("AccessFeature")
local AccessPlayer = require("AccessPlayer")
local AccessPlayerInterface = require("AccessPlayerInterface")
local AccessService = require("AccessService")
local AccessStateUtils = require("AccessStateUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local PlayerMockService = require("PlayerMockService")
local Rx = require("Rx")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local featureCounter = 0

type Controller = {
	maid: Maid.Maid,
	accessDataService: AccessDataService.AccessDataService,
	fakePlayer: () -> Player,
	featureOn: (
		rawName: string,
		initial: boolean?
	) -> (AccessFeature.AccessFeature, ValueObject.ValueObject<boolean?>),
	registerFeature: (feature: AccessFeature.AccessFeature) -> AccessFeature.AccessFeature,
	accessPlayerFor: (player: Player) -> any,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local accessDataService: AccessDataService.AccessDataService = serviceBag:GetService(AccessDataService) :: any
	serviceBag:GetService(AccessService)
	local binder = serviceBag:GetService(AccessPlayer) :: any
	serviceBag:Init()
	serviceBag:Start()

	local playerMockService = serviceBag:GetService(PlayerMockService) :: any

	local controller: Controller = {
		maid = maid,
		accessDataService = accessDataService,
		fakePlayer = function()
			return maid:Add(playerMockService:CreatePlayer())
		end,
		featureOn = function(rawName, initial)
			featureCounter += 1
			local featureName = `{rawName}{featureCounter}`
			local valueObject = maid:Add(ValueObject.new(initial))
			maid:GiveTask(accessDataService:RegisterFact(maid:Add(AccessFact.new(`{featureName}Fact`, {
				resolve = function()
					return valueObject
				end,
			}))))

			local feature = maid:Add(AccessFeature.anyOf(featureName, { `{featureName}Fact` }))
			maid:GiveTask(accessDataService:RegisterFeature(feature))

			return feature, valueObject
		end,
		registerFeature = function(feature)
			maid:Add(feature)
			maid:GiveTask(accessDataService:RegisterFeature(feature))
			return feature
		end,
		accessPlayerFor = function(player)
			local accessPlayer = binder:Get(player)
			assert(accessPlayer, "PlayerBinder did not bind the mock player")
			return accessPlayer
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("AccessPlayer", function()
	it("is bound to a mock player without anything asking it to", function()
		local controller = setup()
		local player = controller.fakePlayer()

		expect(controller.accessPlayerFor(player)).never.toEqual(nil)

		controller:Destroy()
	end)

	it("binds an implementation onto the player, findable through the tie", function()
		local controller = setup()
		local player = controller.fakePlayer()
		controller.accessPlayerFor(player)

		expect(AccessPlayerInterface:HasImplementation(player)).toEqual(true)

		controller:Destroy()
	end)

	it("answers the same question three ways, consistently", function()
		local controller = setup()
		local chapters = controller.featureOn("chapters", true)

		local player = controller.fakePlayer()
		local accessPlayer = controller.accessPlayerFor(player)

		expect(accessPlayer:IsFeatureAllowed(chapters)).toEqual(true)

		local isAllowed = controller.maid:Add(ObservableSpy.new(accessPlayer:ObserveIsFeatureAllowed(chapters)))
		expect(isAllowed:GetLastValue()).toEqual(true)

		controller:Destroy()
	end)

	it("fails closed on unresolved for the boolean, but says unresolved for the state", function()
		local controller = setup()
		local chapters = controller.featureOn("chapters", nil)

		local accessPlayer = controller.accessPlayerFor(controller.fakePlayer())

		expect(accessPlayer:IsFeatureAllowed(chapters)).toEqual(false)
		expect(accessPlayer:GetFeatureAllowedState(chapters)).toEqual(AccessStateUtils.unresolved())

		controller:Destroy()
	end)

	it("fires FeatureAllowedChanged as a verdict changes", function()
		local controller = setup()
		local chapters, ownsChapters = controller.featureOn("chapters", false)

		local accessPlayer = controller.accessPlayerFor(controller.fakePlayer())

		local allowedFeatureNames: { string } = {}
		controller.maid:GiveTask(accessPlayer.FeatureAllowedChanged:Connect(function(featureName, isAllowed)
			if isAllowed then
				table.insert(allowedFeatureNames, featureName)
			end
		end))

		ownsChapters.Value = true

		expect(table.find(allowedFeatureNames, chapters:GetFeatureName())).never.toBeNil()

		controller:Destroy()
	end)

	it("overrides a fact from the player object, server-side", function()
		local controller = setup()
		local chapters = controller.featureOn("chapters", false)

		local player = controller.fakePlayer()
		local accessPlayer = controller.accessPlayerFor(player)

		expect(accessPlayer:IsFeatureAllowed(chapters)).toEqual(false)

		accessPlayer:SetFactOverride(`{chapters:GetFeatureName()}Fact`, true)

		expect(accessPlayer:IsFeatureAllowed(chapters)).toEqual(true)

		controller:Destroy()
	end)

	it("reports every feature verdict in its debug state", function()
		local controller = setup()
		local chapters = controller.featureOn("chapters", true)

		local accessPlayer = controller.accessPlayerFor(controller.fakePlayer())
		local state = accessPlayer:GetDebugState()

		expect(state.featureStates[chapters:GetFeatureName()].allowed).toEqual(true)

		controller:Destroy()
	end)
end)

describe("AccessPlayer and per-thing features", function()
	it("leaves a subject-requiring feature out of the blanket tracking", function()
		local controller = setup()
		local evaluated = false

		controller.registerFeature(AccessFeature.new("eggPurchase", {
			facts = {},
			requiresSubject = true,
			observeCompute = function()
				evaluated = true
				return Rx.of(AccessStateUtils.allowed()) :: any
			end,
		}))

		controller.accessPlayerFor(controller.fakePlayer())

		expect(evaluated).toEqual(false)

		controller:Destroy()
	end)

	it("still answers a per-thing feature when asked with its subject", function()
		local controller = setup()

		local feature = controller.registerFeature(AccessFeature.new("eggPurchase2", {
			facts = {},
			requiresSubject = true,
			observeCompute = function(_observeFacts, subject)
				return Rx.of(
						if subject == "blueEgg" then AccessStateUtils.allowed() else AccessStateUtils.unresolved()
					) :: any
			end,
		}))

		local accessPlayer = controller.accessPlayerFor(controller.fakePlayer())

		expect(accessPlayer:IsFeatureAllowed(feature, "blueEgg")).toEqual(true)

		controller:Destroy()
	end)
end)
