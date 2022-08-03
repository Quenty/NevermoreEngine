--[[
	RxFriendUtils

	Utilities for observing friends on the client.

	O/H, 21/07/22
]]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")

local RxFriendUtils = {}

function RxFriendUtils.observeFriendsInServerAsBrios()
	-- Note that 'PlayerFriendedEvent' and 'PlayerUnfriendedEvent' are currently unreliable.
	-- See: https://devforum.roblox.com/t/getcores-playerfriendedevent-and-playerunfriendedevent-bindableevents-firing-at-inappropriate-times/570403/4
	-- Due to players initially starting with an 'unknown' friend value, they fire for all players in the game at launch, and on the first time another player that joins the server.
	-- This is unexpected, they should really be firing when the state changes between Friended <-> Unfriended!
	-- Therefore, we must also use Player:IsFriendsWith() initially, and then use the below events just for when the state changes.
	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleFriendState(otherPlayer: Player, isFriendsWith)
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

		-- Handle players leaving / joining.
		maid:GiveTask(Players.PlayerRemoving:Connect(function(player: Player)
			maid[player] = nil
		end))
		local function handleNewPlayer(otherPlayer: Player)
			if otherPlayer ~= Players.LocalPlayer then
				-- You can't be friends with yourself!
				-- Pcall as :IsFriendsWith() could throw.
				local success, isFriendsWith = pcall(function()
					return Players.LocalPlayer:IsFriendsWith(otherPlayer.UserId)
				end)
				if not success then
					warn(("[RxFriendUtils] Couldn't get friendship status with %q!"):format(otherPlayer.Name))
				end
				-- If the call failed, then 'isFriendsWith' will be nil.
				-- We'll assume that this player isn't a friend on failure.
				handleFriendState(otherPlayer, isFriendsWith)
			end
		end
		maid:GiveTask(Players.PlayerAdded:Connect(handleNewPlayer))
		for _, otherPlayer in Players:GetPlayers() do
			-- :IsFriendsWith() yields, so we call it in a new thread.
			task.defer(handleNewPlayer, otherPlayer)
		end

		-- Handle changes for players already in this server.
		-- There's a non-zero chance these get removed someday... :(
		-- https://devforum.roblox.com/t/playerfriendedevent-was-deleted-from-corescripts/696683
		-- So just incase these connections throw, use a new thread so we don't error out the whole observable.
		task.spawn(function()
			maid:GiveTask(StarterGui:GetCore("PlayerFriendedEvent").Event:Connect(function(player: Player)
				handleFriendState(player, true)
			end))
			maid:GiveTask(StarterGui:GetCore("PlayerUnfriendedEvent").Event:Connect(function(player: Player)
				handleFriendState(player, false)
			end))
		end)

		return maid
	end)
end

return RxFriendUtils
