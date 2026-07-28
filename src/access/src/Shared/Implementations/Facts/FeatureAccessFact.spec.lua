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
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local accessDataService: AccessDataService.AccessDataService = serviceBag:GetService(AccessDataService) :: any
	serviceBag:Init()
	serviceBag:Start()

	return {
		maid = maid,
		accessDataService = accessDataService,
		fakePlayer = function(): Player
			return maid:Add(PlayerMock.new()) :: any
		end,
		-- A feature granted by one fact the test drives.
		featureOn = function(featureName: string, initial: boolean?)
			local valueObject = maid:Add(ValueObject.new(initial)) :: any
			maid:GiveTask(accessDataService:RegisterFact(maid:Add(AccessFact.new(`{featureName}Fact`, {
				resolve = function()
					return valueObject
				end,
			}))))

			local feature = maid:Add(AccessFeature.anyOf(featureName, { `{featureName}Fact` }))
			maid:GiveTask(accessDataService:RegisterFeature(feature))

			return feature, valueObject
		end,
		observeState = function(player: Player, feature: any)
			local last = nil
			maid:GiveTask(accessDataService:ObserveFeature(player, feature):Subscribe(function(state)
				last = state
			end))
			return function()
				return last
			end
		end,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}
end

describe("FeatureAccessFact", function()
	it("grants a feature composed from another feature's verdict", function()
		local controller = setup()
		local chapters, ownsChapters = controller.featureOn("chapters", true)

		local shop = controller.maid:Add(AccessFeature.anyOf("shop", {}))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(shop))

		local asFact = controller.maid:Add(FeatureAccessFact.new("allowedChapters", chapters))
		controller.maid:GiveTask(controller.accessDataService:RegisterFact(asFact))
		controller.maid:GiveTask(shop:PushFactAllowsFeature(asFact))

		local getState = controller.observeState(controller.fakePlayer(), shop)
		expect(AccessStateUtils.isAllowed(getState() :: any)).toEqual(true)

		ownsChapters.Value = false
		expect(AccessStateUtils.isAllowed(getState() :: any)).toEqual(false)

		controller:destroy()
	end)

	it("keeps unresolved unresolved rather than collapsing it to a refusal", function()
		-- One slow lookup must not become a confident denial three features away.
		local controller = setup()
		local chapters = controller.featureOn("chapters", nil)

		local shop = controller.maid:Add(AccessFeature.anyOf("shop", {}))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(shop))

		local asFact = controller.maid:Add(FeatureAccessFact.new("allowedChapters", chapters))
		controller.maid:GiveTask(controller.accessDataService:RegisterFact(asFact))
		controller.maid:GiveTask(shop:PushFactAllowsFeature(asFact))

		local state = controller.observeState(controller.fakePlayer(), shop)()
		expect(AccessStateUtils.isUnresolved(state :: any)).toEqual(true)

		controller:destroy()
	end)

	it("names the source after the feature it came from, so a readout says where it came from", function()
		local controller = setup()
		local chapters = controller.featureOn("chapters", true)

		local asFact = controller.maid:Add(FeatureAccessFact.new("allowedChapters", chapters))

		expect(asFact:GetSource()).toEqual("feature:chapters")

		controller:destroy()
	end)

	it("settles a cycle as unresolved instead of recursing", function()
		-- The per-player share is connected before its upstream is, so a re-entrant read joins the
		-- in-flight one rather than starting another. Safe, but it does mean a feature that depends on
		-- itself can never say yes.
		local controller = setup()
		local chapters = controller.featureOn("chapters", false)

		local asFact = controller.maid:Add(FeatureAccessFact.new("allowedChapters", chapters))
		controller.maid:GiveTask(controller.accessDataService:RegisterFact(asFact))
		controller.maid:GiveTask(chapters:PushFactAllowsFeature(asFact))

		local state = controller.observeState(controller.fakePlayer(), chapters)()

		expect(AccessStateUtils.isUnresolved(state :: any)).toEqual(true)

		controller:destroy()
	end)
end)
