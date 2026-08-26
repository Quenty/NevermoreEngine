--!strict
--[[
	Coverage for settings cache hydration, which used to recurse until the C stack died: the per-player
	memo was only filled after hydration returned, so a read arriving during hydration's own
	synchronous emission hydrated again -- and each subscription mints a fresh tie interface, so the
	cache map re-emitted and fed the next read.

	A stub implementer stands in for PlayerSettingsClient: the tie plumbing is what is under test, not
	the settings themselves.

	@class SettingsDataService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PlayerSettingsInterface = require("PlayerSettingsInterface")
local PlayerSettingsUtils = require("PlayerSettingsUtils")
local ServiceBag = require("ServiceBag")
local SettingsDataService = require("SettingsDataService")
local TieRealmUtils = require("TieRealmUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local maid = Maid.new()

	local serviceBag = maid:Add(ServiceBag.new())
	local settingsDataService: SettingsDataService.SettingsDataService =
		serviceBag:GetService(SettingsDataService) :: any
	serviceBag:Init()
	serviceBag:Start()

	-- Parented so a test can take it back out, the way a departing player leaves Players.
	local player = maid:Add(PlayerMock.new())
	player.Parent = Workspace

	local getPlayerCalls = 0

	local folder = maid:Add(PlayerSettingsUtils.create())
	folder.Parent = player

	maid:Add(PlayerSettingsInterface:Implement(folder, {
		GetPlayer = function()
			getPlayerCalls += 1
			return player
		end,
		-- The rest only has to exist for the implementation to be valid.
		GetSettingProperty = function() end,
		GetValue = function() end,
		SetValue = function() end,
		ObserveValue = function() end,
		RestoreDefault = function() end,
		EnsureInitialized = function() end,
	}, TieRealmUtils.inferTieRealm()))

	local controller = {
		settingsDataService = settingsDataService,
		player = player,
		getPlayerCalls = function()
			return getPlayerCalls
		end,
		maid = maid,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("SettingsDataService hydration", function()
	it("resolves the same implementation across repeat reads", function()
		local controller = setup()

		local first = controller.settingsDataService:GetPlayerSettings(controller.player)
		local second = controller.settingsDataService:GetPlayerSettings(controller.player)

		expect(first).never.toBeNil()
		expect(second).toBe(first)

		controller:destroy()
	end)

	it("hydrates without invoking the implementation's GetPlayer", function()
		local controller = setup()

		controller.settingsDataService:GetPlayerSettings(controller.player)

		expect(controller.getPlayerCalls()).toBe(0)

		controller:destroy()
	end)

	it("does not re-hydrate when an observer reads settings during a re-hydration", function()
		local controller = setup()
		local settingsDataService = controller.settingsDataService
		local player = controller.player

		local sequence = ""
		controller.maid:GiveTask(settingsDataService:ObservePlayerSettings(player):Subscribe(function(playerSettings)
			sequence ..= if playerSettings ~= nil then "impl," else "nil,"

			-- The re-entrant read: in production, any observer that reads a setting while handling one.
			settingsDataService:GetPlayerSettings(player)
		end))

		expect(sequence).toBe("impl,")

		-- Drops the memo without marking the player gone, so re-hydration is under test here rather than
		-- the departure guard. The observer's own read used to find the memo still empty and hydrate
		-- again, and so on until the C stack died.
		local hydratedPlayersMaid = (settingsDataService :: any)._hydratedPlayersMaid
		hydratedPlayersMaid[player] = nil

		expect(settingsDataService:GetPlayerSettings(player)).never.toBeNil()

		-- One re-hydration, not a cascade: nil is the old hydration tearing down, and the observer's own
		-- read rebuilds from inside that emission.
		expect(sequence).toBe("impl,nil,impl,")

		controller:destroy()
	end)

	it("does not hydrate a player who has left", function()
		local controller = setup()
		local settingsDataService = controller.settingsDataService
		local player = controller.player

		local sequence = ""
		controller.maid:GiveTask(settingsDataService:ObservePlayerSettings(player):Subscribe(function(playerSettings)
			sequence ..= if playerSettings ~= nil then "impl," else "nil,"

			settingsDataService:GetPlayerSettings(player)
		end))

		expect(sequence).toBe("impl,")

		-- Stands in for Players.PlayerRemoving, which no test can make the engine fire.
		local internal: any = settingsDataService
		internal:_onPlayerRemoving(player)

		-- The read from inside the teardown emission finds nothing to rebuild -- the settings folder is
		-- leaving the DataModel too.
		expect(sequence).toBe("impl,nil,")
		expect(settingsDataService:GetPlayerSettings(player)).toBeNil()
		expect(sequence).toBe("impl,nil,")

		controller:destroy()
	end)

	it("stops holding a player once they are out of the DataModel", function()
		local controller = setup()
		local settingsDataService = controller.settingsDataService
		local player = controller.player

		settingsDataService:GetPlayerSettings(player)

		local internal: any = settingsDataService
		internal:_onPlayerRemoving(player)

		-- The tombstone holds the slot for as long as the player could still be asked about.
		expect(internal._hydratedPlayersMaid[player]).never.toBeNil()

		-- What a removed player's instance actually does, and the point after which nothing can reach
		-- these settings again.
		player.Parent = nil

		expect(internal._hydratedPlayersMaid[player]).toBeNil()

		-- With the tombstone gone, the DataModel answers: a later read must not claim the slot back.
		expect(settingsDataService:GetPlayerSettings(player)).toBeNil()
		expect(internal._hydratedPlayersMaid[player]).toBeNil()

		controller:destroy()
	end)
end)
