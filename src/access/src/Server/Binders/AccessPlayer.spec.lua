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
local PlayerMockService = require("PlayerMockService")
local Rx = require("Rx")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local featureCounter = 0

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local accessDataService: AccessDataService.AccessDataService = serviceBag:GetService(AccessDataService) :: any
	-- A binder's class resolves its services during construction, long after the bag has started, so
	-- every dependency has to already be in the bag before Start.
	serviceBag:GetService(AccessService)
	local binder = serviceBag:GetService(AccessPlayer) :: any
	serviceBag:Init()
	serviceBag:Start()

	-- A bare PlayerMock.new() is not tracked, so nothing would discover it and the binder would never bind.
	local playerMockService = serviceBag:GetService(PlayerMockService) :: any

	local controller = {
		maid = maid,
		binder = binder,
		accessDataService = accessDataService,
		fakePlayer = function(): Player
			return maid:Add(playerMockService:CreatePlayer()) :: any
		end,
		featureOn = function(rawName: string, initial: boolean?)
			featureCounter += 1
			local featureName = `{rawName}{featureCounter}`
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
		-- Binding runs off deferred CollectionService signals, so it is waited for rather than assumed.
		accessPlayerFor = function(player: Player)
			local deadline = os.clock() + 2
			while os.clock() < deadline do
				local bound = binder:Get(player)
				if bound then
					return bound
				end
				task.wait()
			end

			error("PlayerBinder did not bind the mock player")
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

		local observed = nil
		controller.maid:GiveTask(accessPlayer:ObserveIsFeatureAllowed(chapters):Subscribe(function(value)
			observed = value
		end))
		expect(observed).toEqual(true)

		controller:Destroy()
	end)

	it("fails closed on unresolved for the boolean, but says unresolved for the state", function()
		local controller = setup()
		local chapters = controller.featureOn("chapters", nil)

		local accessPlayer = controller.accessPlayerFor(controller.fakePlayer())

		expect(accessPlayer:IsFeatureAllowed(chapters)).toEqual(false)
		expect(accessPlayer:GetFeatureAllowedState(chapters).type).toEqual("disallowed")
		expect((accessPlayer:GetFeatureAllowedState(chapters) :: any).reason).toEqual("unresolved")

		controller:Destroy()
	end)

	it("fires FeatureAllowedChanged as a verdict changes", function()
		local controller = setup()
		local chapters, ownsChapters = controller.featureOn("chapters", false)

		local accessPlayer = controller.accessPlayerFor(controller.fakePlayer())

		local fired = {}
		controller.maid:GiveTask(accessPlayer.FeatureAllowedChanged:Connect(function(featureName, isAllowed)
			table.insert(fired, { featureName = featureName, isAllowed = isAllowed })
		end))

		ownsChapters.Value = true

		local sawChapters = false
		for _, entry in fired do
			if entry.featureName == chapters:GetFeatureName() and entry.isAllowed then
				sawChapters = true
			end
		end
		expect(sawChapters).toEqual(true)

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
		-- The tracker walks every registered feature with no subject, and a per-thing gate has no answer
		-- to that question.
		local controller = setup()
		local evaluated = false

		local feature = controller.maid:Add(AccessFeature.new("eggPurchase", {
			facts = {},
			requiresSubject = true,
			observeCompute = function()
				evaluated = true
				return Rx.of(AccessStateUtils.allowed()) :: any
			end,
		}))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))

		controller.accessPlayerFor(controller.fakePlayer())

		expect(evaluated).toEqual(false)

		controller:Destroy()
	end)

	it("still answers a per-thing feature when asked with its subject", function()
		local controller = setup()

		local feature = controller.maid:Add(AccessFeature.new("eggPurchase2", {
			facts = {},
			requiresSubject = true,
			observeCompute = function(_observeFacts, subject)
				return Rx.of(
						if subject == "blueEgg" then AccessStateUtils.allowed() else AccessStateUtils.unresolved()
					) :: any
			end,
		}))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))

		local accessPlayer = controller.accessPlayerFor(controller.fakePlayer())

		expect(accessPlayer:IsFeatureAllowed(feature, "blueEgg")).toEqual(true)

		controller:Destroy()
	end)
end)
