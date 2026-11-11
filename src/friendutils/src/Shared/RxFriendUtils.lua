--!strict
--[=[
	Utilities for observing the local player's friends.

	@class RxFriendUtils
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Brio = require("Brio")
local CoreGuiUtils = require("CoreGuiUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerMock = require("PlayerMock")

local MAX_GET_CORE_ATTEMPTS = 5
local GET_CORE_INITIAL_WAIT_TIME = 0.5

local RxFriendUtils = {}

local function getUserId(player: Player): number
	return if PlayerMock.isMock(player) then PlayerMock.read(player, "UserId") else player.UserId
end

local function readFriendship(observedPlayer: Player, otherPlayer: Player): boolean
	if PlayerMock.isMock(observedPlayer) then
		return PlayerMock.callMethod(observedPlayer, "Player.IsFriendsWithAsync", getUserId(otherPlayer))
	elseif PlayerMock.isMock(otherPlayer) then
		return PlayerMock.callMethod(otherPlayer, "Player.IsFriendsWithAsync", getUserId(observedPlayer))
	end

	return observedPlayer:IsFriendsWithAsync(getUserId(otherPlayer))
end

--[=[
	Observe friends in the current server (not including the LocalPlayer!), useful for social GUIs.
	The lifetimes exist for the whole duration another player is a friend and in your server.
	This means if a player is unfriended + friended multiple times per session, they will have emitted multiple friend lifetimes.

	Works against [PlayerMock] players on either side: mocks in the DataModel are enumerated alongside
	real players, and friendship resolves through the mock's `"Player.IsFriendsWithAsync"` domain. A
	mock local player answers `StarterGui:GetCore` with its own stand-in for the CoreGui events below,
	so a test fires a friending the way the CoreGui does:

	```lua
	PlayerMock.callMethod(player, "StarterGui.GetCore", "PlayerFriendedEvent"):Fire(otherPlayer)
	```

	@param player Player?
	@return Observable<Brio<Player>>
]=]
function RxFriendUtils.observeFriendsInServerAsBrios(player: Player?): Observable.Observable<Brio.Brio<Player>>
	player = player or Players.LocalPlayer

	assert(typeof(player) == "Instance", "Bad player")

	local observedPlayer: Player = player :: Player

	-- Note that 'PlayerFriendedEvent' and 'PlayerUnfriendedEvent' are currently unreliable.
	-- See: https://devforum.roblox.com/t/getcores-playerfriendedevent-and-playerunfriendedevent-bindableevents-firing-at-inappropriate-times/570403/4
	-- Due to players initially starting with an 'unknown' friend value, they fire for all players in the game at launch, and on the first time another player that joins the server.
	-- This is unexpected, they should really be firing when the state changes between Friended <-> Unfriended!
	-- Therefore, we must also use Player:IsFriendsWith() initially, and then use the below events just for when the state changes.
	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleFriendState(otherPlayer: Player, isFriendsWith: boolean)
			if otherPlayer == Players.LocalPlayer then
				return
			end

			if isFriendsWith then
				-- Only create a new brio if we we're not already friends...
				-- As stated above, the CoreGUI event is unreliable and could fire many times!
				if not maid[otherPlayer] then
					local friendshipBrio = Brio.new(otherPlayer)
					maid[otherPlayer] = friendshipBrio
					sub:Fire(friendshipBrio)
				end
			else
				maid[otherPlayer] = nil
			end
		end

		local function handleNewPlayerAsync(otherPlayer: Player)
			if otherPlayer == observedPlayer then
				return
			end

			local isFriendsWith = false
			local ok = pcall(function()
				isFriendsWith = readFriendship(observedPlayer, otherPlayer)
			end)
			if not ok then
				warn(
					string.format(
						"[RxFriendUtils.observeFriendsInServerAsBrios] Couldn't get friendship status with %q!",
						otherPlayer.Name
					)
				)

				-- If the call failed, then 'isFriendsWith' will be nil.
				-- We'll assume that this player isn't a friend on failure.
				handleFriendState(otherPlayer, false)
				return
			end

			handleFriendState(otherPlayer, isFriendsWith)
		end

		local function handlePlayerRemoving(otherPlayer: Player)
			maid[otherPlayer] = nil
		end

		-- Handle players leaving / joining.
		maid:GiveTask(Players.PlayerRemoving:Connect(handlePlayerRemoving))
		maid:GiveTask(Players.PlayerAdded:Connect(handleNewPlayerAsync))

		-- Mocks never appear in Players:GetPlayers()/PlayerAdded; enumerate them through their tag,
		-- mirroring the DataModel-scoped engine calls (see [PlayerMock.TAG]).
		maid:GiveTask(CollectionService:GetInstanceAddedSignal(PlayerMock.TAG):Connect(function(instance)
			handleNewPlayerAsync((instance :: any) :: Player)
		end))
		maid:GiveTask(CollectionService:GetInstanceRemovedSignal(PlayerMock.TAG):Connect(function(instance)
			handlePlayerRemoving((instance :: any) :: Player)
		end))

		for _, otherPlayer in Players:GetPlayers() do
			task.spawn(handleNewPlayerAsync, otherPlayer)
		end

		for _, tagged in CollectionService:GetTagged(PlayerMock.TAG) do
			task.spawn(handleNewPlayerAsync, (tagged :: any) :: Player)
		end

		-- Handle changes for players already in this server.
		-- There's a non-zero chance these get removed someday... :(
		-- https://devforum.roblox.com/t/playerfriendedevent-was-deleted-from-corescripts/696683
		-- So just incase these connections throw, retrieve them off-thread so we don't error out the whole observable.
		-- Only allow this while the game is running too
		local localPlayer = Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()
		if observedPlayer == localPlayer and (RunService:IsRunning() or PlayerMock.isMock(observedPlayer)) then
			-- Getting the core yields, so the subscription may be cleaned up before it resolves.
			local cancelled = false
			maid:GiveTask(function()
				cancelled = true
			end)

			local function connectCoreEvent(coreName: string, isFriendsWith: boolean)
				local promise = maid:GivePromise(
					CoreGuiUtils.promiseRetryGetCore(MAX_GET_CORE_ATTEMPTS, GET_CORE_INITIAL_WAIT_TIME, coreName)
				)

				promise:Then(function(coreEvent)
					if cancelled then
						return
					end

					maid:GiveTask(coreEvent.Event:Connect(function(otherPlayer: Player)
						handleFriendState(otherPlayer, isFriendsWith)
					end))
				end, function(err)
					if cancelled then
						return
					end

					warn(`[RxFriendUtils] Couldn't get core {coreName}: {tostring(err)}`)
				end)
			end

			connectCoreEvent("PlayerFriendedEvent", true)
			connectCoreEvent("PlayerUnfriendedEvent", false)
		end

		return maid
	end) :: any
end

return RxFriendUtils
