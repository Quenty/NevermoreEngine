--!strict
--[[
	Unit coverage for PlayerProductManagerBase._canQueryCloudOwnership: whether this process can ask the
	cloud about a given player's ownership. A client holds a PlayerProductManager for every player -- the
	tag replicates, so the binder builds one per player -- but may only ask the marketplace about its own,
	so this is what keeps a doomed request per player per asset from being made at all.

	Driven against a fake `self` rather than a constructed manager: the predicate reads only `_player`, and
	building a manager would need a ServiceBag, the GameConfig graph, and a real Player the cloud test
	place has none of. A designated [PlayerMock] stands in for the local player, and the process seam
	stands in for being a client -- a --cloud run is a server, so the client branch is otherwise
	unreachable.

	@class PlayerProductManagerBase.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PlayerProductManagerBase = require("PlayerProductManagerBase")
local Workspace = game:GetService("Workspace")

local afterEach = Jest.Globals.afterEach
local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local jest = Jest.Globals.jest

-- Spied once and re-implemented between tests rather than restored and re-spied, matching
-- TeleportServiceUtils.spec: jest.restoreAllMocks clears the spy state but not the per-object mock
-- registry, so a second spyOn of the same method hands back the cached mock without reinstalling it.
local realIsClientProcess = (PlayerProductManagerBase :: any)._isClientProcess
local isClientProcessSpy = jest.spyOn(PlayerProductManagerBase :: any, "_isClientProcess")

local function pretendClientProcess(): ()
	isClientProcessSpy.mockReturnValue(true)
end

local function pretendServerProcess(): ()
	isClientProcessSpy.mockReturnValue(false)
end

local created: { any } = {}

afterEach(function()
	isClientProcessSpy.mockImplementation(realIsClientProcess)
	PlayerMock.setMockedLocalPlayer(nil)

	for _, instance in created do
		instance:Destroy()
	end
	table.clear(created)
end)

local function canQueryCloudOwnership(player: any): boolean
	return (PlayerProductManagerBase :: any)._canQueryCloudOwnership({ _player = player })
end

-- A Folder without the mock tag: PlayerMock.isMock requires both, so this fails it and stands in for a
-- real player, which a server-run spec cannot otherwise have.
local function newNonMockPlayer(): any
	local player = Instance.new("Folder")
	player.Name = "NotAPlayerMock"
	table.insert(created, player)
	return player
end

local function newMock(): any
	local mock: any = PlayerMock.new()
	table.insert(created, mock)
	return mock
end

-- Parented before designating: the designation is a CollectionService tag, and GetTagged only resolves
-- instances in the DataModel.
local function designateLocal(mock: any): ()
	mock.Parent = Workspace
	PlayerMock.setMockedLocalPlayer(mock)
end

describe("PlayerProductManagerBase._canQueryCloudOwnership()", function()
	it("should let a server process ask about anybody", function()
		designateLocal(newMock())
		pretendServerProcess()

		expect(canQueryCloudOwnership(newNonMockPlayer())).toEqual(true)
	end)

	it("should refuse a client process asking about a player that is not its own", function()
		designateLocal(newMock())
		pretendClientProcess()

		expect(canQueryCloudOwnership(newNonMockPlayer())).toEqual(false)
	end)

	it("should let a client process ask about its own player", function()
		local localMock = newMock()
		designateLocal(localMock)
		pretendClientProcess()

		expect(canQueryCloudOwnership(localMock)).toEqual(true)
	end)

	it("should let a client process ask about another mock, which never reaches the engine", function()
		designateLocal(newMock())
		pretendClientProcess()

		expect(canQueryCloudOwnership(newMock())).toEqual(true)
	end)

	it("should let a client process with no local player ask", function()
		pretendClientProcess()

		-- No player to be is not a client to speak for: left able to ask, rather than unwiring ownership
		-- for the very player the manager is about.
		expect(canQueryCloudOwnership(newNonMockPlayer())).toEqual(true)
	end)
end)
