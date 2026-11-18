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
local ObservableSpy = require("ObservableSpy")
local PlayerIsAdminAccessFact = require("PlayerIsAdminAccessFact")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	maid: Maid.Maid,
	accessDataService: AccessDataService.AccessDataService,
	newPlayer: () -> Player,
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
		newPlayer = function()
			return maid:Add(PlayerMock.new())
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
		local controller = setup()

		controller.maid:GiveTask(controller.accessDataService:AddAccessFact(AccessFactNames.PLAYER_IS_ADMIN, true, {
			priority = AccessFactPriority.ELEVATED,
			source = "gameAllowlist",
		}))

		local feature = controller.maid:Add(AccessFeature.anyOf("staffTools", { AccessFactNames.PLAYER_IS_ADMIN }))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))

		local states = controller.maid:Add(
			ObservableSpy.new(controller.accessDataService:ObserveFeature(controller.newPlayer(), feature))
		)

		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

		controller:Destroy()
	end)

	it("refuses to build without a service bag", function()
		expect(function()
			PlayerIsAdminAccessFact.new(nil :: any)
		end).toThrow("No serviceBag")
	end)
end)
