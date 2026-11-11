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
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PlayerProductManagerBase = require("PlayerProductManagerBase")
local Workspace = game:GetService("Workspace")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local jest = Jest.Globals.jest

-- Spied once and re-implemented between tests rather than restored and re-spied, matching
-- TeleportServiceUtils.spec: jest.restoreAllMocks clears the spy state but not the per-object mock
-- registry, so a second spyOn of the same method hands back the cached mock without reinstalling it.
local realIsClientProcess = (PlayerProductManagerBase :: any)._isClientProcess
local isClientProcessSpy = jest.spyOn(PlayerProductManagerBase :: any, "_isClientProcess")

local function canQueryCloudOwnership(player: any): boolean
	return (PlayerProductManagerBase :: any)._canQueryCloudOwnership({ _player = player })
end

local function setup()
	local maid = Maid.new()

	maid:GiveTask(function()
		isClientProcessSpy.mockImplementation(realIsClientProcess)
	end)

	local function pretendClientProcess(): ()
		isClientProcessSpy.mockReturnValue(true)
	end

	local function pretendServerProcess(): ()
		isClientProcessSpy.mockReturnValue(false)
	end

	-- A Folder without the mock tag: PlayerMock.isMock requires both, so this fails it and stands in for a
	-- real player, which a server-run spec cannot otherwise have.
	local function newNonMockPlayer(): any
		local player = Instance.new("Folder")
		player.Name = "NotAPlayerMock"
		maid:GiveTask(player)
		return player
	end

	local function newMock(): any
		local mock: any = PlayerMock.new()
		maid:GiveTask(mock)
		return mock
	end

	-- Parented before designating: the designation is a CollectionService tag, and GetTagged only resolves
	-- instances in the DataModel.
	local function designateLocal(mock: any): ()
		mock.Parent = Workspace
		maid:Add(PlayerMock.setMockedLocalPlayer(mock))
	end

	local controller = {
		pretendClientProcess = pretendClientProcess,
		pretendServerProcess = pretendServerProcess,
		newNonMockPlayer = newNonMockPlayer,
		newMock = newMock,
		designateLocal = designateLocal,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("PlayerProductManagerBase._canQueryCloudOwnership()", function()
	it("should let a server process ask about anybody", function()
		local controller = setup()

		controller.designateLocal(controller.newMock())
		controller.pretendServerProcess()

		expect(canQueryCloudOwnership(controller.newNonMockPlayer())).toEqual(true)

		controller:Destroy()
	end)

	it("should refuse a client process asking about a player that is not its own", function()
		local controller = setup()

		controller.designateLocal(controller.newMock())
		controller.pretendClientProcess()

		expect(canQueryCloudOwnership(controller.newNonMockPlayer())).toEqual(false)

		controller:Destroy()
	end)

	it("should let a client process ask about its own player", function()
		local controller = setup()

		local localMock = controller.newMock()
		controller.designateLocal(localMock)
		controller.pretendClientProcess()

		expect(canQueryCloudOwnership(localMock)).toEqual(true)

		controller:Destroy()
	end)

	it("should let a client process ask about another mock, which never reaches the engine", function()
		local controller = setup()

		controller.designateLocal(controller.newMock())
		controller.pretendClientProcess()

		expect(canQueryCloudOwnership(controller.newMock())).toEqual(true)

		controller:Destroy()
	end)

	it("should let a client process with no local player ask", function()
		local controller = setup()

		controller.pretendClientProcess()

		-- No player to be is not a client to speak for: left able to ask, rather than unwiring ownership
		-- for the very player the manager is about.
		expect(canQueryCloudOwnership(controller.newNonMockPlayer())).toEqual(true)

		controller:Destroy()
	end)
end)
