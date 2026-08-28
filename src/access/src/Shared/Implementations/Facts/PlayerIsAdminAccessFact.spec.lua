--!strict
--[[
	@class PlayerIsAdminAccessFact.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessDataService = require("AccessDataService")
local AccessFactNames = require("AccessFactNames")
local AccessFactPriority = require("AccessFactPriority")
local AccessFeature = require("AccessFeature")
local AccessStateUtils = require("AccessStateUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerIsAdminAccessFact = require("PlayerIsAdminAccessFact")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")

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
		serviceBag = serviceBag,
		accessDataService = accessDataService,
		maid = maid,
		fakePlayer = function(): Player
			return maid:Add(PlayerMock.new()) :: any
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("PlayerIsAdminAccessFact", function()
	it("is pre-registered, so a feature can declare it without the game wiring anything", function()
		local controller = setup()

		expect(controller.accessDataService:HasFact(AccessFactNames.PLAYER_IS_ADMIN)).toEqual(true)

		controller:Destroy()
	end)

	it("sits at the built-in priority so anything a game registers outranks it", function()
		local controller = setup()

		local layers = controller.accessDataService:GetFactLayers(AccessFactNames.PLAYER_IS_ADMIN)
		expect(#layers).toEqual(1)
		expect(layers[1]:GetPriority()).toEqual(AccessFactPriority.BUILT_IN)

		controller:Destroy()
	end)

	it("is named in the readout by the mechanism behind it", function()
		local controller = setup()

		local layers = controller.accessDataService:GetFactLayers(AccessFactNames.PLAYER_IS_ADMIN)
		expect(layers[1]:GetSource()).toEqual("permission")

		controller:Destroy()
	end)

	it("lets a game layer its own answer over the built-in one", function()
		-- The reason BUILT_IN is the bottom: a game with its own idea of who counts as staff should not
		-- have to fight the package for the name.
		local controller = setup()

		controller.maid:GiveTask(controller.accessDataService:AddAccessFact(AccessFactNames.PLAYER_IS_ADMIN, true, {
			priority = AccessFactPriority.ELEVATED,
			source = "gameAllowlist",
		}))

		local feature = controller.maid:Add(AccessFeature.anyOf("staffTools", { AccessFactNames.PLAYER_IS_ADMIN }))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))

		local last = nil
		controller.maid:GiveTask(
			controller.accessDataService:ObserveFeature(controller.fakePlayer(), feature):Subscribe(function(state)
				last = state
			end)
		)

		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(true)

		controller:Destroy()
	end)

	it("refuses to build without a service bag", function()
		expect(function()
			PlayerIsAdminAccessFact.new(nil :: any)
		end).toThrow("No serviceBag")
	end)
end)
