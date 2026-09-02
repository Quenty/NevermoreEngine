--!strict
--[=[
	The mock's stand-ins for what the `Players` service answers: which mock is the local player, and
	which mock a userId resolves to. The local-player designation is a tag on the mock itself rather
	than Lua module state, so a destroyed mock takes it along.

	Use [PlayerMock.setMockedLocalPlayer], [PlayerMock.getMockedLocalPlayer] and
	[PlayerMock.getMockByUserId].

	@class PlayerMockPlayerServiceUtils
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")

local PlayerMockConstants = require("PlayerMockConstants")
local PlayerMockPropertyUtils = require("PlayerMockPropertyUtils")
local PlayerMockUtils = require("PlayerMockUtils")

local PlayerMockPlayerServiceUtils = {}

--[=[
	Returns the mock in the DataModel whose `UserId` stand-in matches, or nil. The mock counterpart of
	`Players:GetPlayerByUserId`. Real UserIds are unique; seed mocks the same way, since the first
	match wins.

	Use [PlayerMock.getMockByUserId].

	@param userId number
	@return Player?
]=]
function PlayerMockPlayerServiceUtils.getPlayerByUserId(userId: number): Player?
	assert(type(userId) == "number", "Bad userId")

	for _, tagged in CollectionService:GetTagged(PlayerMockConstants.MOCK_TAG) do
		if PlayerMockUtils.isMock(tagged) then
			local mock = (tagged :: any) :: Player
			if PlayerMockPropertyUtils.read(mock, "UserId") == userId then
				return mock
			end
		end
	end

	return nil
end

--[=[
	Returns the disposer that restores the previous designation.

	Use [PlayerMock.setMockedLocalPlayer].

	@param player Player? -- must be a PlayerMock in the DataModel, or nil to clear
	@return () -> () -- Restores the previous designation. Safe to call more than once.
]=]
function PlayerMockPlayerServiceUtils.setMockedLocalPlayer(player: Player?): () -> ()
	assert(player == nil or PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(
		player == nil or (player :: Instance):IsDescendantOf(game),
		"PlayerMock must be parented into the DataModel to be designated the local player"
	)

	local previous = PlayerMockUtils.getMockedLocalPlayer()

	PlayerMockPlayerServiceUtils._applyMockedLocalPlayer(player)

	local disposed = false
	return function()
		if disposed then
			return
		end
		disposed = true

		if PlayerMockUtils.getMockedLocalPlayer() ~= player then
			return
		end

		if previous ~= nil and not (previous :: Instance):IsDescendantOf(game) then
			previous = nil
		end

		PlayerMockPlayerServiceUtils._applyMockedLocalPlayer(previous)
	end
end

function PlayerMockPlayerServiceUtils._applyMockedLocalPlayer(player: Player?)
	-- Only one mock can be the local player at a time.
	for _, tagged in CollectionService:GetTagged(PlayerMockConstants.LOCAL_PLAYER_TAG) do
		CollectionService:RemoveTag(tagged, PlayerMockConstants.LOCAL_PLAYER_TAG)
	end

	if player ~= nil then
		(player :: Instance):AddTag(PlayerMockConstants.LOCAL_PLAYER_TAG)
	end
end

return PlayerMockPlayerServiceUtils
