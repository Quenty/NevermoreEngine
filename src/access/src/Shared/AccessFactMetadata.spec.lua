--!strict
--[[
	Attribution: a fact says not just whether, but why. "You own this" is far less useful to a UI than
	"you own this because of gamepass 12345", and a friend-granted fact is nearly useless without knowing
	which friend.

	@class AccessFactMetadata.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessCommandUtils = require("AccessCommandUtils")
local AccessDataService = require("AccessDataService")
local AccessFact = require("AccessFact")
local AccessFactContributionState = require("AccessFactContributionState")
local AccessFactPriority = require("AccessFactPriority")
local AccessFeature = require("AccessFeature")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
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

	local controller = {
		maid = maid,
		accessDataService = accessDataService,
		fakePlayer = function(): Player
			return maid:Add(PlayerMock.new()) :: any
		end,
		attributedFact = function(factName: string, initial: any, options: { priority: number?, source: string? }?)
			local valueObject = maid:Add(ValueObject.new(initial)) :: any
			maid:GiveTask(accessDataService:RegisterFact(maid:Add(AccessFact.new(factName, {
				resolve = function()
					return valueObject
				end,
				priority = if options then options.priority else nil,
				source = if options then options.source else nil,
			}))))
			return valueObject
		end,
		report = function(player: Player, factName: string): any
			local last = nil
			maid:GiveTask(accessDataService:ObserveFactReport(player, factName):Subscribe(function(value)
				last = value
			end))
			return last
		end,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("AccessFact.contribution", function()
	it("carries attribution alongside the answer", function()
		local controller = setup()
		controller.attributedFact("ownsGamePass", AccessFact.contribution(true, { gamePassId = 12345 }))

		local report = controller.report(controller.fakePlayer(), "ownsGamePass")

		expect(report.value).toEqual(true)
		expect(report.metadata.gamePassId).toEqual(12345)

		controller:destroy()
	end)

	it("leaves metadata nil for a plain answer, so the common case stays plain", function()
		local controller = setup()
		controller.attributedFact("ownsGamePass", true)

		expect(controller.report(controller.fakePlayer(), "ownsGamePass").metadata).toEqual(nil)

		controller:destroy()
	end)

	it("reports the deciding layer's attribution, not an outranked one's", function()
		-- The layers that lost did not decide anything, and their reasons would misattribute.
		local controller = setup()
		controller.attributedFact("isStaff", AccessFact.contribution(true, { via = "groupRank" }), {
			source = "groupRank",
		})
		controller.attributedFact("isStaff", AccessFact.contribution(true, { via = "allowlist" }), {
			priority = AccessFactPriority.ELEVATED,
			source = "allowlist",
		})

		local report = controller.report(controller.fakePlayer(), "isStaff")

		expect(report.decidedBy).toEqual("allowlist")
		expect(report.metadata.via).toEqual("allowlist")

		controller:destroy()
	end)

	it("keeps every layer's attribution visible underneath", function()
		local controller = setup()
		controller.attributedFact("isStaff", AccessFact.contribution(true, { via = "groupRank" }), {
			source = "groupRank",
		})
		controller.attributedFact("isStaff", AccessFact.contribution(true, { via = "allowlist" }), {
			priority = AccessFactPriority.ELEVATED,
			source = "allowlist",
		})

		local report = controller.report(controller.fakePlayer(), "isStaff")

		expect(report.layers[2].metadata.via).toEqual("allowlist")
		expect(report.layers[3].metadata.via).toEqual("groupRank")

		controller:destroy()
	end)

	it("follows attribution as it changes, which is what a UI subscribes to", function()
		-- Which friend granted you access is not fixed for the session.
		local controller = setup()
		local grant = controller.attributedFact("friendAccess", AccessFact.contribution(true, { userId = 1 }))

		local player = controller.fakePlayer()
		expect(controller.report(player, "friendAccess").metadata.userId).toEqual(1)

		grant.Value = AccessFact.contribution(true, { userId = 2 })

		expect(controller.report(player, "friendAccess").metadata.userId).toEqual(2)

		controller:destroy()
	end)

	it("still grants the feature it is attached to", function()
		local controller = setup()
		controller.attributedFact("ownsGamePass", AccessFact.contribution(true, { gamePassId = 12345 }))

		local feature = controller.maid:Add(AccessFeature.anyOf("shop", { "ownsGamePass" }))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))

		expect(controller.accessDataService:IsFeatureAllowedByName(controller.fakePlayer(), "shop")).toEqual(true)

		controller:destroy()
	end)
end)

describe("AccessCommandUtils.describeMetadata", function()
	it("renders nothing when a layer attached none", function()
		expect(AccessCommandUtils.describeMetadata(nil)).toEqual("")
		expect(AccessCommandUtils.describeMetadata({})).toEqual("")
	end)

	it("renders keys in a stable order, so two readouts compare", function()
		expect(AccessCommandUtils.describeMetadata({ b = 2, a = 1 })).toEqual(" [a=1 b=2]")
	end)

	it("renders a bare value too", function()
		expect(AccessCommandUtils.describeMetadata(12345)).toEqual(" [12345]")
	end)

	it("shows attribution in the fact readout", function()
		local text = AccessCommandUtils.formatFactReport({
			factName = "ownsGamePass",
			state = AccessFactContributionState.ALLOW,
			value = true,
			metadata = { gamePassId = 12345 },
			decidedBy = "purchase",
			layers = {
				{
					source = "purchase",
					priority = 0,
					state = AccessFactContributionState.ALLOW,
					contributes = true,
					value = true,
					metadata = { gamePassId = 12345 },
					decided = true,
				},
			},
		})

		expect(string.find(text, "gamePassId=12345") ~= nil).toEqual(true)
	end)
end)

describe("attribution across replication", function()
	it("rides with a replicated answer, which is where it matters most", function()
		-- "Which friend granted this" is resolved on the server and rendered on the client. Losing it in
		-- transit would strand the most useful metadata the package carries on the wrong realm.
		local controller = setup()

		local player = controller.fakePlayer()
		controller.accessDataService:SetServerFactValue(player, "friendAccess", true, false, { grantedByUserId = 42 })

		local report = controller.report(player, "friendAccess")

		expect(report.value).toEqual(true)
		expect(report.decidedBy).toEqual("replicated")
		expect(report.metadata.grantedByUserId).toEqual(42)

		controller:destroy()
	end)

	it("shows the replicated attribution on its own layer", function()
		local controller = setup()

		local player = controller.fakePlayer()
		controller.accessDataService:SetServerFactValue(player, "friendAccess", true, false, { grantedByUserId = 42 })

		local report = controller.report(player, "friendAccess")

		local replicated = nil
		for _, layer in report.layers do
			if layer.source == "replicated" then
				replicated = layer
			end
		end

		expect((replicated :: any).metadata.grantedByUserId).toEqual(42)

		controller:destroy()
	end)
end)
