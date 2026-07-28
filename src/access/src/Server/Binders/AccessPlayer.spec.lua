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
local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMockService = require("PlayerMockService")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local featureCounter = 0

local function makeController()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local accessDataService: AccessDataService.AccessDataService = serviceBag:GetService(AccessDataService) :: any
	-- Boots the entry point, the way a game does. Hand-assembling a partial bag is what broke this
	-- first: a binder's class resolves its services during construction, which happens long after the
	-- bag has started, so every dependency has to already be in the bag before Start.
	serviceBag:GetService(AccessService)
	local binder = serviceBag:GetService(AccessPlayer) :: any
	serviceBag:Init()
	serviceBag:Start()

	-- PlayerBinder declares this dependency in Init, so it is already in the bag by the time we ask.
	-- Mocks have to come from the service: a bare PlayerMock.new() is not tracked, so nothing would
	-- discover it and the binder would never bind.
	local playerMockService = serviceBag:GetService(PlayerMockService) :: any

	return {
		maid = maid,
		binder = binder,
		accessDataService = accessDataService,
		fakePlayer = function(): Player
			return maid:Add(playerMockService:CreatePlayer()) :: any
		end,
		-- A feature granted by one fact the test drives. Names are made unique because the bag is shared
		-- across this file and a registry refuses duplicates.
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
		-- No explicit Bind: PlayerBinder is meant to discover mocks the same way it discovers real joins,
		-- and every test here leans on that rather than papering over it. Binding runs off deferred
		-- CollectionService signals, so it is waited for rather than assumed synchronous.
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
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}
end

-- A bag per test, torn down with it. The AccessPlayer tag is global, so a binder that outlives its test
-- goes on binding every player mock a later test creates and overwriting the facts attribute with its own
-- registry -- which is invisible here and breaks whoever is actually reading that attribute.
local function setup()
	return makeController()
end

describe("AccessPlayer", function()
	it("is bound to a mock player without anything asking it to", function()
		-- PlayerBinder is supposed to respect mocks the same way it respects real joins. If it stops,
		-- every spec in this file that holds an AccessPlayer is testing nothing.
		local controller = setup()
		local player = controller.fakePlayer()

		expect(controller.accessPlayerFor(player)).never.toEqual(nil)

		controller:destroy()
	end)

	it("binds an implementation onto the player, findable through the tie", function()
		-- The point: anything holding a Player can ask, without requiring the package.
		local controller = setup()
		local player = controller.fakePlayer()
		controller.accessPlayerFor(player)

		expect(AccessPlayerInterface:HasImplementation(player)).toEqual(true)

		controller:destroy()
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

		controller:destroy()
	end)

	it("fails closed on unresolved for the boolean, but says unresolved for the state", function()
		-- A boolean has nowhere to put a third answer; the state does.
		local controller = setup()
		local chapters = controller.featureOn("chapters", nil)

		local accessPlayer = controller.accessPlayerFor(controller.fakePlayer())

		expect(accessPlayer:IsFeatureAllowed(chapters)).toEqual(false)
		expect(accessPlayer:GetFeatureAllowedState(chapters).type).toEqual("disallowed")
		expect((accessPlayer:GetFeatureAllowedState(chapters) :: any).reason).toEqual("unresolved")

		controller:destroy()
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

		controller:destroy()
	end)

	it("overrides a fact from the player object, server-side", function()
		local controller = setup()
		local chapters = controller.featureOn("chapters", false)

		local player = controller.fakePlayer()
		local accessPlayer = controller.accessPlayerFor(player)

		expect(accessPlayer:IsFeatureAllowed(chapters)).toEqual(false)

		accessPlayer:SetFactOverride(`{chapters:GetFeatureName()}Fact`, true)

		expect(accessPlayer:IsFeatureAllowed(chapters)).toEqual(true)

		controller:destroy()
	end)

	it("reports every feature verdict in its debug state", function()
		local controller = setup()
		local chapters = controller.featureOn("chapters", true)

		local accessPlayer = controller.accessPlayerFor(controller.fakePlayer())
		local state = accessPlayer:GetDebugState()

		expect(state.featureStates[chapters:GetFeatureName()].allowed).toEqual(true)

		controller:destroy()
	end)
end)
