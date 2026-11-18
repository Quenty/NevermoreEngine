--!strict
--[[
	@class AccessFact.Metadata.spec.lua
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
	newPlayer: () -> Player,
	attributedFact: (
		factName: string,
		initial: any,
		options: { priority: number?, source: string? }?
	) -> ValueObject.ValueObject<any>,
	observeReport: (
		player: Player,
		factName: string
	) -> ObservableSpy.ObservableSpy<AccessDataService.AccessFactReport>,
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
		attributedFact = function(factName, initial, options)
			local valueObject = maid:Add(ValueObject.new(initial))
			maid:GiveTask(accessDataService:RegisterFact(maid:Add(AccessFact.new(factName, {
				resolve = function()
					return valueObject
				end,
				priority = if options then options.priority else nil,
				source = if options then options.source else nil,
			}))))
			return valueObject
		end,
		observeReport = function(player, factName)
			return maid:Add(ObservableSpy.new(accessDataService:ObserveFactReport(player, factName)))
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("AccessFact.contribution", function()
	it("carries attribution alongside the answer", function()
		local controller = setup()
		controller.attributedFact("ownsGamePass", AccessFact.contribution(true, { gamePassId = 12345 }))

		local report = controller.observeReport(controller.newPlayer(), "ownsGamePass"):GetLastValue()

		expect(report.value).toEqual(true)
		expect(report.metadata).toEqual({ gamePassId = 12345 })

		controller:Destroy()
	end)

	it("leaves metadata nil for a plain answer, so the common case stays plain", function()
		local controller = setup()
		controller.attributedFact("ownsGamePass", true)

		expect(controller.observeReport(controller.newPlayer(), "ownsGamePass"):GetLastValue().metadata).toBeNil()

		controller:Destroy()
	end)

	it("reports the deciding layer's attribution, not an outranked one's", function()
		local controller = setup()
		controller.attributedFact("isStaff", AccessFact.contribution(true, { via = "groupRank" }), {
			source = "groupRank",
		})
		controller.attributedFact("isStaff", AccessFact.contribution(true, { via = "allowlist" }), {
			priority = AccessFactPriority.ELEVATED,
			source = "allowlist",
		})

		local report = controller.observeReport(controller.newPlayer(), "isStaff"):GetLastValue()

		expect(report.decidedBy).toEqual("allowlist")
		expect(report.metadata).toEqual({ via = "allowlist" })

		controller:Destroy()
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

		local report = controller.observeReport(controller.newPlayer(), "isStaff"):GetLastValue()

		expect(report.layers[2].metadata).toEqual({ via = "allowlist" })
		expect(report.layers[3].metadata).toEqual({ via = "groupRank" })

		controller:Destroy()
	end)

	it("follows attribution as it changes, which is what a UI subscribes to", function()
		local controller = setup()
		local grant = controller.attributedFact("friendAccess", AccessFact.contribution(true, { userId = 1 }))

		local reports = controller.observeReport(controller.newPlayer(), "friendAccess")
		expect(reports:GetLastValue().metadata).toEqual({ userId = 1 })

		grant.Value = AccessFact.contribution(true, { userId = 2 })

		expect(reports:GetLastValue().metadata).toEqual({ userId = 2 })

		controller:Destroy()
	end)

	it("still grants the feature it is attached to", function()
		local controller = setup()
		controller.attributedFact("ownsGamePass", AccessFact.contribution(true, { gamePassId = 12345 }))

		local feature = controller.maid:Add(AccessFeature.anyOf("shop", { "ownsGamePass" }))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))

		expect(controller.accessDataService:IsFeatureAllowedByName(controller.newPlayer(), "shop")).toEqual(true)

		controller:Destroy()
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

		expect(text).toContain("gamePassId=12345")
	end)
end)

describe("attribution across replication", function()
	it("rides with a replicated answer, which is where it matters most", function()
		local controller = setup()

		local player = controller.newPlayer()
		controller.accessDataService:SetServerFactValue(player, "friendAccess", true, false, { grantedByUserId = 42 })

		local report = controller.observeReport(player, "friendAccess"):GetLastValue()

		expect(report.value).toEqual(true)
		expect(report.decidedBy).toEqual("replicated")
		expect(report.metadata).toEqual({ grantedByUserId = 42 })

		controller:Destroy()
	end)

	it("shows the replicated attribution on its own layer", function()
		local controller = setup()

		local player = controller.newPlayer()
		controller.accessDataService:SetServerFactValue(player, "friendAccess", true, false, { grantedByUserId = 42 })

		local report = controller.observeReport(player, "friendAccess"):GetLastValue()

		local replicated = nil
		for _, layer in report.layers do
			if layer.source == "replicated" then
				replicated = layer
			end
		end

		expect((replicated :: any).metadata).toEqual({ grantedByUserId = 42 })

		controller:Destroy()
	end)
end)
