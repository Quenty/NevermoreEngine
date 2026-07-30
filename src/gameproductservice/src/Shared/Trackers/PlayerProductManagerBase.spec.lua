--!strict
--[[
	Unit coverage for PlayerProductManagerBase._canQueryCloudOwnership: which realm may ask the cloud
	about whose ownership. A client holds a manager for every player (the PlayerProductManager tag
	replicates) but may only ask the marketplace about the local one, so this is what keeps a doomed
	request per player per asset from being made at all.

	Driven against a fake `self` -- a player and a tie realm -- rather than a constructed manager: the
	predicate reads only those two, and building a manager would need a ServiceBag, the GameConfig graph,
	and a real Player the cloud test place has none of. A designated [PlayerMock] stands in for the local
	player, which a server-run spec has no real one of.

	@class PlayerProductManagerBase.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PlayerProductManagerBase = require("PlayerProductManagerBase")
local TieRealms = require("TieRealms")
local Workspace = game:GetService("Workspace")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function canQueryCloudOwnership(player: any, tieRealm: string): boolean
	return (PlayerProductManagerBase :: any)._canQueryCloudOwnership({
		_player = player,
		_tieRealmService = {
			GetTieRealm = function()
				return tieRealm
			end,
		},
	})
end

-- A Folder with no mock tag: PlayerMock.isMock rejects it, so it stands in for a real player without
-- the spec needing one.
local function makeNonMockPlayer(): any
	return Instance.new("Folder")
end

local function makeDesignatedLocalMock(): (any, () -> ())
	-- Parented before designating: the designation is a CollectionService tag, and GetTagged only
	-- resolves instances in the DataModel.
	local mock: any = PlayerMock.new()
	mock.Parent = Workspace
	PlayerMock.setMockedLocalPlayer(mock)

	return mock, function()
		PlayerMock.setMockedLocalPlayer(nil)
		mock:Destroy()
	end
end

describe("PlayerProductManagerBase._canQueryCloudOwnership()", function()
	it("should let a server realm ask about anybody", function()
		local player = makeNonMockPlayer()
		local mock, destroy = makeDesignatedLocalMock()
		expect(mock).never.toBeNil()

		expect(canQueryCloudOwnership(player, TieRealms.SERVER)).toEqual(true)

		destroy()
		player:Destroy()
	end)

	it("should refuse a client realm asking about a player that is not the local one", function()
		local player = makeNonMockPlayer()
		local _mock, destroy = makeDesignatedLocalMock()

		expect(canQueryCloudOwnership(player, TieRealms.CLIENT)).toEqual(false)

		destroy()
		player:Destroy()
	end)

	it("should let a client realm ask about the local player", function()
		local mock, destroy = makeDesignatedLocalMock()

		expect(canQueryCloudOwnership(mock, TieRealms.CLIENT)).toEqual(true)

		destroy()
	end)

	it("should let a client realm ask about another mock, which never reaches the engine", function()
		local _localMock, destroy = makeDesignatedLocalMock()
		local otherMock: any = PlayerMock.new()

		expect(canQueryCloudOwnership(otherMock, TieRealms.CLIENT)).toEqual(true)

		otherMock:Destroy()
		destroy()
	end)

	it("should let a realm with no local player at all ask", function()
		local player = makeNonMockPlayer()

		-- No client to be is a bare unit test rather than a client: left able to ask, rather than
		-- silently unwiring ownership for the very player the manager is about.
		expect(canQueryCloudOwnership(player, TieRealms.CLIENT)).toEqual(true)

		player:Destroy()
	end)
end)
