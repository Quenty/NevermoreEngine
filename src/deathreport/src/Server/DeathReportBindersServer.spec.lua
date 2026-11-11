--!strict
--[[
	@class DeathReportBindersServer.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DeathReportBindersServer = require("DeathReportBindersServer")
local DeathReportService = require("DeathReportService")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerDeathTracker = require("PlayerDeathTracker")
local PlayerKillTracker = require("PlayerKillTracker")
local ServiceBag = require("ServiceBag")
local TeamKillTracker = require("TeamKillTracker")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local serviceBag = ServiceBag.new()
	serviceBag:GetService(DeathReportService)
	local provider = serviceBag:GetService(DeathReportBindersServer)
	serviceBag:Init()
	serviceBag:Start()

	maid:GiveTask(function()
		serviceBag:Destroy()
	end)

	local controller = {
		serviceBag = serviceBag,
		provider = provider,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("DeathReportBindersServer", function()
	it("exposes the same binders the service bag hands out", function()
		local controller = setup()

		expect(controller.provider.TeamKillTracker).toBe(controller.serviceBag:GetService(TeamKillTracker))
		expect(controller.provider.PlayerKillTracker).toBe(controller.serviceBag:GetService(PlayerKillTracker))
		expect(controller.provider.PlayerDeathTracker).toBe(controller.serviceBag:GetService(PlayerDeathTracker))

		controller:Destroy()
	end)

	it("resolves binders by tag", function()
		local controller = setup()

		local ok, binder = controller.provider:PromiseBinder("TeamKillTracker"):Yield()
		expect(ok).toBe(true)
		expect(binder).toBe(controller.serviceBag:GetService(TeamKillTracker))
		expect(controller.provider:Get("Unknown")).toBeNil()

		controller:Destroy()
	end)
end)
