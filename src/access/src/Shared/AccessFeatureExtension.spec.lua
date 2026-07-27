--!strict
--[[
	The extensibility story end-to-end: the package ships `owns-game` reading a purchase, and a game
	unions a gamepass and a staff allowlist on top without editing the feature or replacing it.

	@class AccessFeatureExtension.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessDataService = require("AccessDataService")
local AccessFact = require("AccessFact")
local AccessFactNames = require("AccessFactNames")
local AccessStateUtils = require("AccessStateUtils")
local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")
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

	local ownsGame = assert(accessDataService:GetFeature(WellKnownAccessFeatureNames.OWNS_GAME), "No owns-game feature")

	return {
		maid = maid,
		accessDataService = accessDataService,
		ownsGame = ownsGame,
		fakePlayer = function(): Player
			return maid:Add(PlayerMock.new()) :: any
		end,
		-- Registers a fact the test drives, and pushes it onto owns-game as another way in.
		pushGrant = function(factName: string, initial: boolean?)
			local valueObject = maid:Add(ValueObject.new(initial)) :: any
			maid:GiveTask(accessDataService:RegisterFact(AccessFact.new(factName, {
				resolve = function()
					return valueObject
				end,
			})))
			maid:GiveTask(ownsGame:PushFactAllowsFeature(accessDataService:GetFactLayers(factName)[1]))
			return valueObject
		end,
		observeAllowed = function(player: Player)
			local last = nil
			maid:GiveTask(accessDataService:ObserveFeature(player, ownsGame):Subscribe(function(state)
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

describe("the shipped owns-game feature", function()
	it("is registered out of the box", function()
		local controller = setup()

		expect(controller.accessDataService:HasFeature(WellKnownAccessFeatureNames.OWNS_GAME)).toEqual(true)
		expect(controller.accessDataService:HasFact(AccessFactNames.OWNS_GAME)).toEqual(true)

		controller:destroy()
	end)

	it("reads only the purchase before anything is pushed onto it", function()
		local controller = setup()

		expect(controller.ownsGame:GetFactNames()).toEqual({ AccessFactNames.OWNS_GAME })

		controller:destroy()
	end)
end)

describe("AccessFeature.PushFactAllowsFeature", function()
	it("widens the feature's declared facts", function()
		local controller = setup()
		controller.pushGrant("ownsGamePass", false)
		controller.pushGrant("isStaff", false)

		local names = controller.ownsGame:GetFactNames()
		expect(#names).toEqual(3)
		expect(table.find(names, "ownsGamePass") ~= nil).toEqual(true)
		expect(table.find(names, "isStaff") ~= nil).toEqual(true)

		controller:destroy()
	end)

	it("grants the feature when a pushed fact says yes", function()
		-- The whole point: nobody owns the game, but the gamepass gets them in, and every consumer
		-- already gating on owns-game picks it up without knowing the gamepass exists.
		local controller = setup()
		local ownsPass = controller.pushGrant("ownsGamePass", false)

		local player = controller.fakePlayer()
		local getState = controller.observeAllowed(player)
		expect(AccessStateUtils.isAllowed(getState() :: any)).toEqual(false)

		ownsPass.Value = true

		expect(AccessStateUtils.isAllowed(getState() :: any)).toEqual(true)

		controller:destroy()
	end)

	it("reaches consumers that subscribed before the push", function()
		-- A push has to reach live subscriptions, or a menu rendered at join never learns about the new
		-- way in.
		local controller = setup()

		local player = controller.fakePlayer()
		local getState = controller.observeAllowed(player)

		controller.pushGrant("isStaff", true)

		expect(AccessStateUtils.isAllowed(getState() :: any)).toEqual(true)

		controller:destroy()
	end)

	it("names every fact that granted, not just the first", function()
		local controller = setup()
		controller.pushGrant("ownsGamePass", true)
		controller.pushGrant("isStaff", true)

		local state = controller.observeAllowed(controller.fakePlayer())() :: any

		expect(#state.grantedBy).toEqual(2)

		controller:destroy()
	end)

	it("only widens -- a pushed fact reading false cannot deny what another granted", function()
		local controller = setup()
		controller.pushGrant("ownsGamePass", true)
		controller.pushGrant("isStaff", false)

		local state = controller.observeAllowed(controller.fakePlayer())() :: any

		expect(AccessStateUtils.isAllowed(state)).toEqual(true)

		controller:destroy()
	end)

	it("narrows again when the push is disposed", function()
		local controller = setup()
		local valueObject = controller.maid:Add(ValueObject.new(true :: boolean?)) :: any
		controller.maid:GiveTask(controller.accessDataService:RegisterFact(AccessFact.new("ownsGamePass", {
			resolve = function()
				return valueObject
			end,
		})))

		local remove =
			controller.ownsGame:PushFactAllowsFeature(controller.accessDataService:GetFactLayers("ownsGamePass")[1])

		local getState = controller.observeAllowed(controller.fakePlayer())
		expect(AccessStateUtils.isAllowed(getState() :: any)).toEqual(true)

		remove()

		expect(AccessStateUtils.isAllowed(getState() :: any)).toEqual(false)
		expect(controller.ownsGame:GetFactNames()).toEqual({ AccessFactNames.OWNS_GAME })

		controller:destroy()
	end)

	it("ignores a push of a fact the feature already reads", function()
		-- Otherwise the remover handed to the second caller would revoke the first caller's grant.
		local controller = setup()

		local remove = controller.ownsGame:PushFactAllowsFeature(
			controller.accessDataService:GetFactLayers(AccessFactNames.OWNS_GAME)[1]
		)
		remove()

		expect(controller.ownsGame:GetFactNames()).toEqual({ AccessFactNames.OWNS_GAME })

		controller:destroy()
	end)
end)
