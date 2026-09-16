--!strict
--[=[
	The child instances a mock carries: the `PlayerGui` and `PlayerScripts` stand-ins the engine
	inserts at join, and the `Backpack` and `StarterGear` it inserts alongside a character spawn.

	Use [PlayerMock.getPlayerGui], [PlayerMock.getPlayerScripts], [PlayerMock.getBackpack] and
	[PlayerMock.getStarterGear].

	@class PlayerMockChildrenUtils
]=]

local require = require(script.Parent.loader).load(script)

local PlayerMockConstants = require("PlayerMockConstants")
local PlayerMockUtils = require("PlayerMockUtils")

local PlayerMockChildrenUtils = {}

--[=[
	Inserts the `PlayerGui` and `PlayerScripts` stand-ins the engine creates at join. Neither is
	`Instance.new`-able, so like the mock itself they are Folders.

	Use [PlayerMock.new].

	@param player Player -- must be a PlayerMock
]=]
function PlayerMockChildrenUtils.seedContainers(player: Player): ()
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")

	local playerGui = Instance.new("Folder")
	playerGui.Name = PlayerMockConstants.PLAYER_GUI_NAME
	playerGui.Parent = player :: Instance

	local playerScripts = Instance.new("Folder")
	playerScripts.Name = PlayerMockConstants.PLAYER_SCRIPTS_NAME
	playerScripts.Parent = player :: Instance
end

--[=[
	Returns the mock's `PlayerGui` stand-in.

	Use [PlayerMock.getPlayerGui].

	@param player Player -- must be a PlayerMock
	@return PlayerGui
]=]
function PlayerMockChildrenUtils.getPlayerGui(player: Player): PlayerGui
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")

	local playerGui: any =
		assert((player :: Instance):FindFirstChild(PlayerMockConstants.PLAYER_GUI_NAME), "No PlayerGui")

	return playerGui :: PlayerGui
end

--[=[
	Returns the mock's `PlayerScripts` stand-in.

	Use [PlayerMock.getPlayerScripts].

	@param player Player -- must be a PlayerMock
	@return PlayerScripts
]=]
function PlayerMockChildrenUtils.getPlayerScripts(player: Player): PlayerScripts
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")

	local playerScripts: any =
		assert((player :: Instance):FindFirstChild(PlayerMockConstants.PLAYER_SCRIPTS_NAME), "No PlayerScripts")

	return playerScripts :: PlayerScripts
end

--[=[
	Returns the mock's current `Backpack` stand-in, or nil before the first spawn.

	Use [PlayerMock.getBackpack].

	@param player Player -- must be a PlayerMock
	@return Backpack?
]=]
function PlayerMockChildrenUtils.getBackpack(player: Player): Backpack?
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")

	return (player :: Instance):FindFirstChildOfClass("Backpack")
end

--[=[
	Returns the mock's current `StarterGear` stand-in, or nil before the first spawn.

	Use [PlayerMock.getStarterGear].

	@param player Player -- must be a PlayerMock
	@return StarterGear?
]=]
function PlayerMockChildrenUtils.getStarterGear(player: Player): StarterGear?
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")

	return (player :: Instance):FindFirstChildOfClass("StarterGear")
end

return PlayerMockChildrenUtils
