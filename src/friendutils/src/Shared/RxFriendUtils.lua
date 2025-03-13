--!strict
--[=[
	Utilities for observing the local player's friends.

	@class RxFriendUtils
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")

local RxFriendUtils = {}

--[=[
	Observe friends in the current server (not including the LocalPlayer!), useful for social GUIs.
	The lifetimes exist for the whole duration another player is a friend and in your server.
	This means if a player is unfriended + friended multiple times per session, they will have emitted multiple friend lifetimes.

	@param player Player?
	@return Observable<Brio<Player>>
]=]
function RxFriendUtils.observeFriendsInServerAsBrios(player: Player?): Observable.Observable<Brio.Brio<Player>>
	player = player or Players.LocalPlayer

	assert(typeof(player) == "Instance", "Bad player")

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
			if otherPlayer ~= player then
				local ok, isFriendsWith = pcall(function()
					return player:IsFriendsWith(otherPlayer.UserId)
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
		end

		-- Handle players leaving / joining.
		maid:GiveTask(Players.PlayerRemoving:Connect(function(otherPlayer: Player)
			maid[otherPlayer] = nil
		end))
		maid:GiveTask(Players.PlayerAdded:Connect(handleNewPlayerAsync))

		for _, otherPlayer in Players:GetPlayers() do
			task.spawn(handleNewPlayerAsync, otherPlayer)
		end

		-- Handle changes for players already in this server.
		-- There's a non-zero chance these get removed someday... :(
		-- https://devforum.roblox.com/t/playerfriendedevent-was-deleted-from-corescripts/696683
		-- So just incase these connections throw, use a new thread so we don't error out the whole observable.
		-- Only allow this while the game is running too
		if player == Players.LocalPlayer and RunService:IsRunning() then
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
