--!strict
--[[
	Boots the client entry point the way a game does, which is the only place the question below can be
	asked: a client-realm policy that nobody added a player to is registered, enabled, listed by
	`access-policies` -- and silent. Every seam test around it passes, because they all call
	[AccessPolicyService.AddPlayer] themselves.

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

local function setup(options: SetupOptions?)
	local opts: SetupOptions = options or {}
	local maid = Maid.new()

	-- Parented before designating: the designation is carried as a tag, and an unparented mock reads back
	-- as nil.
	local localPlayer = maid:Add(PlayerMock.new()) :: any
	localPlayer.Parent = Workspace

	if opts.designateLocalPlayer ~= false then
		maid:GiveTask(PlayerMock.setMockedLocalPlayer(localPlayer))
	end

	local otherPlayer = maid:Add(PlayerMock.new()) :: any
	otherPlayer.Parent = Workspace

	local serviceBag = maid:Add(ServiceBag.new())
	-- Before Init, which only infers a realm when it has not been given one. This runner is a server, so
	-- without it every client-realm policy here would be skipped for the wrong reason.
	local tieRealmService: any = serviceBag:GetService(TieRealmService)
	tieRealmService:SetTieRealm(TieRealms.CLIENT)

	local accessPolicyService: any = serviceBag:GetService(AccessPolicyService)
	serviceBag:GetService(AccessServiceClient)
	serviceBag:Init()

	policyCounter += 1
	local appliedFor: { Player } = {}

	-- Registered between Init and Start, because Start is where the entry point adds the player: a policy
	-- registered after it would have missed the only application this realm ever makes.
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

	local controller = {
		maid = maid,
		serviceBag = serviceBag,
		accessPolicyService = accessPolicyService,
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
			setup()
		end).never.toThrow()
	end)

	--[[
		The regression: nothing else on the client ever adds a player, so an enabled client-realm policy --
		a paywall screen, a locked banner -- simply never ran in a real game.
	]]
	it("runs a client-realm policy for the local player, with nobody having added them", function()
		local controller = setup()

		expect(controller.appliedFor).toEqual({ controller.localPlayer })
	end)

	--[[
		Player instances replicate, so this realm can answer questions about everybody here. Applying to them
		would raise this client's screen on somebody else's verdict.
	]]
	it("adds only the local player, not everybody the client can see", function()
		local controller = setup()

		expect(table.find(controller.appliedFor, controller.otherPlayer)).toBeNil()
	end)

	it("leaves a server-realm policy to the server", function()
		local controller = setup({ realm = AccessPolicyRealm.SERVER })

		expect(controller.appliedFor).toEqual({})
	end)

	-- Asserted against the undesignated mock rather than against an empty list: the designation is ambient,
	-- so a mock another spec left designated would be adopted here and is not this test's business.
	it("starts without a local player rather than erroring", function()
		local controller = setup({ designateLocalPlayer = false })

		expect(table.find(controller.appliedFor, controller.localPlayer)).toBeNil()
	end)
end)
