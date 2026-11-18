--!strict
--[[
	@class FeatureAccessFact.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessDataService = require("AccessDataService")
local AccessFact = require("AccessFact")
local AccessFeature = require("AccessFeature")
local AccessStateUtils = require("AccessStateUtils")
local FeatureAccessFact = require("FeatureAccessFact")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	maid: Maid.Maid,
	accessDataService: AccessDataService.AccessDataService,
	fakePlayer: () -> Player,
	featureOn: (
		featureName: string,
		initial: boolean?
	) -> (AccessFeature.AccessFeature, ValueObject.ValueObject<boolean?>),
	registerShop: () -> AccessFeature.AccessFeature,
	observeStates: (
		player: Player,
		feature: AccessFeature.AccessFeature
	) -> ObservableSpy.ObservableSpy<AccessStateUtils.AccessState>,
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
			return maid:Add(PlayerMock.new())
		end,
		featureOn = function(featureName, initial)
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
		registerShop = function()
			local shop = maid:Add(AccessFeature.anyOf("shop", {}))
			maid:GiveTask(accessDataService:RegisterFeature(shop))
			return shop
		end,
		observeStates = function(player, feature)
			return maid:Add(ObservableSpy.new(accessDataService:ObserveFeature(player, feature)))
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("FeatureAccessFact", function()
	it("grants a feature composed from another feature's verdict", function()
		local controller = setup()
		local chapters, ownsChapters = controller.featureOn("chapters", true)
		local shop = controller.registerShop()

		local asFact = controller.maid:Add(FeatureAccessFact.new("allowedChapters", chapters))
		controller.maid:GiveTask(controller.accessDataService:RegisterFact(asFact))
		controller.maid:GiveTask(shop:PushFactAllowsFeature(asFact))

		local states = controller.observeStates(controller.fakePlayer(), shop)
		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

		ownsChapters.Value = false
		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(false)

		controller:Destroy()
	end)

	it("keeps unresolved unresolved rather than collapsing it to a refusal", function()
		local controller = setup()
		local chapters = controller.featureOn("chapters", nil)
		local shop = controller.registerShop()

		local asFact = controller.maid:Add(FeatureAccessFact.new("allowedChapters", chapters))
		controller.maid:GiveTask(controller.accessDataService:RegisterFact(asFact))
		controller.maid:GiveTask(shop:PushFactAllowsFeature(asFact))

		local states = controller.observeStates(controller.fakePlayer(), shop)
		expect(AccessStateUtils.isUnresolved(states:GetLastValue())).toEqual(true)

		controller:Destroy()
	end)

	it("names the source after the feature it came from, so a readout says where it came from", function()
		local controller = setup()
		local chapters = controller.featureOn("chapters", true)

		local asFact = controller.maid:Add(FeatureAccessFact.new("allowedChapters", chapters))

		expect(asFact:GetSource()).toEqual("feature:chapters")

		controller:Destroy()
	end)

	it("settles a cycle as unresolved instead of recursing", function()
		local controller = setup()
		local chapters = controller.featureOn("chapters", false)

		local asFact = controller.maid:Add(FeatureAccessFact.new("allowedChapters", chapters))
		controller.maid:GiveTask(controller.accessDataService:RegisterFact(asFact))
		controller.maid:GiveTask(chapters:PushFactAllowsFeature(asFact))

		local states = controller.observeStates(controller.fakePlayer(), chapters)

		expect(AccessStateUtils.isUnresolved(states:GetLastValue())).toEqual(true)

		controller:Destroy()
	end)
end)
