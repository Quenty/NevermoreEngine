--!strict
--[=[
	Helper methods for finding and retrieving the [PlayerGui] instance
	@class PlayerGuiUtils
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Observable = require("Observable")
local PlayerMock = require("PlayerMock")
local PlayerMockUtils = require("PlayerMockUtils")
local Rx = require("Rx")

local PlayerGuiUtils = {}

--[=[
	Finds the current player gui for the [Players.LocalPlayer] property or errors.

	:::warning
	This method errors if it can't find the PlayerGui. Fortunately, the PlayerGui is pretty much
	guaranteed to exist in most scenarios.
	:::

	@return PlayerGui
]=]
function PlayerGuiUtils.getPlayerGui(): PlayerGui
	local localPlayer = Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()
	if not localPlayer then
		error("[PlayerGuiUtils.getPlayerGui] - No localPlayer")
	end

	if PlayerMock.isMock(localPlayer) then
		return PlayerMock.getPlayerGui(localPlayer)
	end

	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		error("[PlayerGuiUtils.getPlayerGui] - No playerGui")
	end

	return playerGui
end

--[=[
	Finds the current player gui for the [Players.LocalPlayer] property.

	@return PlayerGui | nil
]=]
function PlayerGuiUtils.findPlayerGui(): PlayerGui?
	local localPlayer = Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()
	if not localPlayer then
		return nil
	end

	if PlayerMock.isMock(localPlayer) then
		return PlayerMock.getPlayerGui(localPlayer)
	end

	return localPlayer:FindFirstChildOfClass("PlayerGui")
end

--[=[
	Observes the current player gui. On a real client this is static -- the engine inserts the
	PlayerGui before any client script runs and never replaces it. Headless (no `Players.LocalPlayer`)
	it follows the [PlayerMock] local-player designation, which a test may make or change after
	subscription (see [PlayerMock.setMockedLocalPlayer]).

	@return Observable<PlayerGui | nil>
]=]
function PlayerGuiUtils.observePlayerGui(): Observable.Observable<PlayerGui?>
	if Players.LocalPlayer then
		return Rx.of(PlayerGuiUtils.findPlayerGui()) :: any
	end

	return PlayerMockUtils.observeMockedLocalPlayer():Pipe({
		Rx.map(function(localPlayer: Player?): PlayerGui?
			if localPlayer ~= nil then
				return PlayerMock.getPlayerGui(localPlayer)
			end

			return nil
		end) :: any,
	}) :: any
end

return PlayerGuiUtils
