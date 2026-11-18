--!strict
--[[
	@class AccessServiceClient.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local AccessPolicy = require("AccessPolicy")
local AccessPolicyRealm = require("AccessPolicyRealm")
local AccessPolicyService = require("AccessPolicyService")
local AccessServiceClient = require("AccessServiceClient")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")
local TieRealms = require("TieRealms")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local policyCounter = 0

type SetupOptions = {
	designateLocalPlayer: boolean?,
	realm: string?,
}

type Controller = {
	maid: Maid.Maid,
	localPlayer: Player,
	otherPlayer: Player,
	appliedFor: { Player },
	Destroy: (self: Controller) -> (),
}

local function setup(options: SetupOptions?): Controller
	local opts: SetupOptions = options or {}
	local maid = Maid.new()

	local localPlayer = maid:Add(PlayerMock.new())
	localPlayer.Parent = Workspace

	if opts.designateLocalPlayer ~= false then
		maid:GiveTask(PlayerMock.setMockedLocalPlayer(localPlayer))
	end

	local otherPlayer = maid:Add(PlayerMock.new())
	otherPlayer.Parent = Workspace

	local serviceBag = maid:Add(ServiceBag.new())
	local tieRealmService: any = serviceBag:GetService(TieRealmService)
	tieRealmService:SetTieRealm(TieRealms.CLIENT)

	local accessPolicyService: any = serviceBag:GetService(AccessPolicyService)
	serviceBag:GetService(AccessServiceClient)
	serviceBag:Init()

	policyCounter += 1
	local appliedFor: { Player } = {}

	maid:GiveTask(accessPolicyService:RegisterPolicy(maid:Add(AccessPolicy.new(serviceBag, {
		policyName = `recordApplied{policyCounter}`,
		realm = opts.realm or AccessPolicyRealm.CLIENT,
		isEnabledByDefault = true,
		apply = function(context)
			table.insert(appliedFor, context.player)
			return nil
		end,
	}))))

	serviceBag:Start()

	local controller: Controller = {
		maid = maid,
		localPlayer = localPlayer,
		otherPlayer = otherPlayer,
		appliedFor = appliedFor,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("AccessServiceClient", function()
	it("initializes and starts, command service and all", function()
		expect(function()
			setup():Destroy()
		end).never.toThrow()
	end)

	it("runs a client-realm policy for the local player, with nobody having added them", function()
		local controller = setup()

		expect(controller.appliedFor).toEqual({ controller.localPlayer })

		controller:Destroy()
	end)

	it("adds only the local player, not everybody the client can see", function()
		local controller = setup()

		expect(table.find(controller.appliedFor, controller.otherPlayer)).toBeNil()

		controller:Destroy()
	end)

	it("leaves a server-realm policy to the server", function()
		local controller = setup({ realm = AccessPolicyRealm.SERVER })

		expect(controller.appliedFor).toEqual({})

		controller:Destroy()
	end)

	it("starts without a local player rather than erroring", function()
		local controller = setup({ designateLocalPlayer = false })

		expect(table.find(controller.appliedFor, controller.localPlayer)).toBeNil()

		controller:Destroy()
	end)
end)
