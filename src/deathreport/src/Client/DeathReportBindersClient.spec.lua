--!strict
--[[
	@class DeathReportBindersClient.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DeathReportBindersClient = require("DeathReportBindersClient")
local DeathReportServiceClient = require("DeathReportServiceClient")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerDeathTrackerClient = require("PlayerDeathTrackerClient")
local PlayerKillTrackerClient = require("PlayerKillTrackerClient")
local ServiceBag = require("ServiceBag")
local TeamKillTrackerClient = require("TeamKillTrackerClient")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local serviceBag = ServiceBag.new()
	serviceBag:GetService(DeathReportServiceClient)
	local provider = serviceBag:GetService(DeathReportBindersClient)
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

describe("DeathReportBindersClient", function()
	it("exposes the same binders the service bag hands out", function()
		local controller = setup()

		expect(controller.provider.TeamKillTracker).toBe(controller.serviceBag:GetService(TeamKillTrackerClient))
		expect(controller.provider.PlayerKillTracker).toBe(controller.serviceBag:GetService(PlayerKillTrackerClient))
		expect(controller.provider.PlayerDeathTracker).toBe(controller.serviceBag:GetService(PlayerDeathTrackerClient))

		controller:Destroy()
	end)

	it("resolves binders by tag", function()
		local controller = setup()

		local ok, binder = controller.provider:PromiseBinder("PlayerKillTracker"):Yield()
		expect(ok).toBe(true)
		expect(binder).toBe(controller.serviceBag:GetService(PlayerKillTrackerClient))
		expect(controller.provider:Get("Unknown")).toBeNil()

		controller:Destroy()
	end)
end)
