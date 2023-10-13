--[=[
	Utilities for observing players
	@class RxPlayerUtils
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")

local RxPlayerUtils = {}

--[=[
	Observe players for the lifetime they exist
	@param predicate callback
	@return Observable<Brio<Player>>
]=]
function RxPlayerUtils.observePlayersBrio(predicate: (Player) -> boolean)
	assert(type(predicate) == "function" or predicate == nil, "Bad predicate!")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handlePlayer(player)
			if predicate == nil or predicate(player) then
				local brio = Brio.new(player)
				maid[player] = brio

				sub:Fire(brio)
			end
		end

		maid:GiveTask(Players.PlayerAdded:Connect(handlePlayer))

		maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
			maid[player] = nil
		end))

		for _, player in Players:GetPlayers() do
			task.spawn(function()
				handlePlayer(player)
			end)
		end

		return maid
	end)
end

--[=[
	Observe players as they're added, and as they are.
	@param predicate callback
	@return Observable<Player>
]=]
function RxPlayerUtils.observePlayers(predicate: (Player) -> boolean)
	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handlePlayer(player)
			if predicate == nil or predicate(player) then
				sub:Fire(player)
			end
		end

		maid:GiveTask(Players.PlayerAdded:Connect(handlePlayer))

		for _, player in Players:GetPlayers() do
			handlePlayer(player)
		end

		return maid
	end)
end

return RxPlayerUtils