--!strict
--[[
	Coverage for the setting property a definition hands out: reused per (serviceBag, player), and its
	observable neither rebuilds nor re-emits when the tie behind it churns. Callers routinely ask for a
	property inline, and a tie mints a new interface per subscription -- so without these, reading a
	setting from inside another setting's observer fans out work on every emission.

	A stub implementer stands in for PlayerSettingsClient, returning the default for everything: the
	plumbing between definition, property, and cache is what is under test, not stored values.

	@class SettingDefinition.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PlayerSettingsInterface = require("PlayerSettingsInterface")
local PlayerSettingsUtils = require("PlayerSettingsUtils")
local Rx = require("Rx")
local ServiceBag = require("ServiceBag")
local SettingDefinition = require("SettingDefinition")
local SettingsDataService = require("SettingsDataService")
local TieRealmUtils = require("TieRealmUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local SETTING_NAME = "TestSetting"
local DEFAULT_VALUE = false

local function setup()
	local maid = Maid.new()

	local serviceBag = maid:Add(ServiceBag.new())
	-- Requested up front: SettingProperty only resolves it lazily, which a started bag rejects.
	serviceBag:GetService(SettingsDataService)
	serviceBag:Init()
	serviceBag:Start()

	-- Settings are not hydrated for a player outside the DataModel.
	local player = maid:Add(PlayerMock.new())
	player.Parent = Workspace

	local folder = maid:Add(PlayerSettingsUtils.create())
	folder.Parent = player

	local implementer = {
		GetPlayer = function()
			return player
		end,
		GetValue = function(_self, _settingName, defaultValue)
			return defaultValue
		end,
		ObserveValue = function(_self, _settingName, defaultValue)
			return Rx.of(defaultValue)
		end,
		EnsureInitialized = function() end,
		GetSettingProperty = function() end,
		SetValue = function() end,
		RestoreDefault = function() end,
	}

	local implementationMaid = maid:Add(Maid.new())
	local function implement()
		implementationMaid._current =
			PlayerSettingsInterface:Implement(folder, implementer, TieRealmUtils.inferTieRealm())
	end
	implement()

	local controller = {
		serviceBag = serviceBag,
		player = player,
		definition = SettingDefinition.new(SETTING_NAME, DEFAULT_VALUE),
		-- Swaps in an equivalent implementation -- the container churn that mints the new interface
		-- identity downstream sees.
		reimplement = implement,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("SettingDefinition.GetSettingProperty", function()
	it("reuses the property for the same serviceBag and player", function()
		local controller = setup()

		local first = controller.definition:GetSettingProperty(controller.serviceBag, controller.player)
		local second = controller.definition:GetSettingProperty(controller.serviceBag, controller.player)

		expect(second).toBe(first)

		controller:destroy()
	end)

	it("keeps a separate property per player", function()
		local controller = setup()
		local otherPlayer = PlayerMock.new()
		otherPlayer.Parent = Workspace

		local property = controller.definition:GetSettingProperty(controller.serviceBag, controller.player)
		local otherProperty = controller.definition:GetSettingProperty(controller.serviceBag, otherPlayer)

		expect(otherProperty).never.toBe(property)

		otherPlayer:Destroy()
		controller:destroy()
	end)
end)

describe("SettingProperty.Observe", function()
	it("reuses the observable across calls", function()
		local controller = setup()
		local property = controller.definition:GetSettingProperty(controller.serviceBag, controller.player)

		expect(property:Observe()).toBe(property:Observe())

		controller:destroy()
	end)

	it("does not re-emit when the tie churns but the value does not", function()
		local controller = setup()
		local property = controller.definition:GetSettingProperty(controller.serviceBag, controller.player)

		local emissions = 0
		local maid = Maid.new()
		maid:GiveTask(property:Observe():Subscribe(function()
			emissions += 1
		end))

		expect(emissions).toBe(1)

		controller.reimplement()
		controller.reimplement()

		expect(emissions).toBe(1)

		maid:DoCleaning()
		controller:destroy()
	end)
end)
