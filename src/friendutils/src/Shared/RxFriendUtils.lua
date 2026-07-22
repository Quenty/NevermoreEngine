--!strict
--[=[
	Utilities for observing the local player's friends.

	@class RxFriendUtils
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerMock = require("PlayerMock")

local RxFriendUtils = {}

local function getUserId(player: Player): number
	return if PlayerMock.isMock(player) then PlayerMock.read(player, "UserId") else player.UserId
end

--[=[
	Observe friends in the current server (not including the LocalPlayer!), useful for social GUIs.
	The lifetimes exist for the whole duration another player is a friend and in your server.
	This means if a player is unfriended + friended multiple times per session, they will have emitted multiple friend lifetimes.

	Works against [PlayerMock] players on either side: mocks in the DataModel are enumerated
	alongside real players, friendship resolves from the mock's "Player.IsFriendsWithAsync" lookup
	domain, and a mid-test [PlayerMock.writeLookup] to that domain stands in for the CoreGui
	friended/unfriended events -- the observable re-reads and emits/kills lifetimes accordingly.

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

		-- Per-otherPlayer wiring (mock friendship-changed connections). Separate from the brio keyed
		-- under maid[otherPlayer]: an unfriend kills the brio but the wiring must survive so a
		-- re-friend emits a new lifetime. Both die together when the other player leaves.
		local listenMaid = maid:Add(Maid.new())

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

			-- Friendship is symmetric, so with only one side mocked the injected state lives on
			-- whichever player is the mock; with both mocked, on the observed player.
			local lookupMock: Player? = nil
			local lookupKey: number? = nil
			if PlayerMock.isMock(observedPlayer) then
				lookupMock = observedPlayer
				lookupKey = getUserId(otherPlayer)
			elseif PlayerMock.isMock(otherPlayer) then
				lookupMock = otherPlayer
				lookupKey = getUserId(observedPlayer)
			end

			if lookupMock ~= nil and lookupKey ~= nil then
				local mock: Player, key: number = lookupMock, lookupKey

				local function readFriendState()
					handleFriendState(otherPlayer, PlayerMock.readLookup(mock, "Player.IsFriendsWithAsync", key))
				end

				-- The lookup attribute's changed signal stands in for the CoreGui friended /
				-- unfriended events below, which only the engine can fire.
				listenMaid[otherPlayer] = PlayerMock.getLookupChangedSignal(mock, "Player.IsFriendsWithAsync", key)
					:Connect(readFriendState)

				readFriendState()
				return
			end

			local isFriendsWith = false
			local ok = pcall(function()
				isFriendsWith = observedPlayer:IsFriendsWithAsync(getUserId(otherPlayer))
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
			listenMaid[otherPlayer] = nil
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
		-- So just incase these connections throw, use a new thread so we don't error out the whole observable.
		-- Only allow this while the game is running too
		if observedPlayer == Players.LocalPlayer and RunService:IsRunning() then
			task.spawn(function()
				maid:GiveTask(StarterGui:GetCore("PlayerFriendedEvent").Event:Connect(function(otherPlayer: Player)
					handleFriendState(otherPlayer, true)
				end))
				maid:GiveTask(StarterGui:GetCore("PlayerUnfriendedEvent").Event:Connect(function(otherPlayer: Player)
					handleFriendState(otherPlayer, false)
				end))
			end)
		end

		return maid
	end) :: any
end

return RxFriendUtils
