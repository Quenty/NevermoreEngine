--!strict
--[=[
	Utilities for observing players
	@class RxPlayerUtils
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxCharacterUtils = require("RxCharacterUtils")
local RxInstanceUtils = require("RxInstanceUtils")

local RxPlayerUtils = {}

--[=[
	Observe players for the lifetime they exist
	@param predicate ((Player) -> boolean)?
	@return Observable<Brio<Player>>
]=]
function RxPlayerUtils.observePlayersBrio(predicate: Rx.Predicate<Player>?): Observable.Observable<Brio.Brio<Player>>
	assert(type(predicate) == "function" or predicate == nil, "Bad predicate!")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handlePlayer(player: Player)
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
	end) :: any
end

--[=[
	Observes the character model for the player
]=]
function RxPlayerUtils.observeCharactersBrio(): Observable.Observable<Brio.Brio<Model>>
	return RxPlayerUtils.observePlayersBrio():Pipe({
		RxBrioUtils.flatMapBrio(function(player)
			return RxCharacterUtils.observeLastCharacterBrio(player)
		end),
	})
end

--[=[
	Observes the character model for the player
]=]
function RxPlayerUtils.observeHumanoidsBrio(): Observable.Observable<Brio.Brio<Humanoid>>
	return RxPlayerUtils.observePlayersBrio():Pipe({
		RxBrioUtils.flatMapBrio(function(player)
			return RxCharacterUtils.observeLastHumanoidBrio(player)
		end),
	})
end

--[=[
	Observes the current local player

	@return Observable<Brio<Player>>
]=]
function RxPlayerUtils.observeLocalPlayerBrio(): Observable.Observable<Brio.Brio<Player>>
	return RxInstanceUtils.observePropertyBrio(Players, "LocalPlayer", function(value)
		return value ~= nil
	end)
end

--[=[
	Observe players as they're added, and as they are.
	@param predicate ((Player) -> boolean)?
	@return Observable<Player>
]=]
function RxPlayerUtils.observePlayers(predicate: Rx.Predicate<Player>?): Observable.Observable<Player>
	assert(type(predicate) == "function" or predicate == nil, "Bad predicate")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handlePlayer(player: Player)
			if predicate == nil or predicate(player) then
				sub:Fire(player)
			end
		end

		maid:GiveTask(Players.PlayerAdded:Connect(handlePlayer))

		for _, player in Players:GetPlayers() do
			task.spawn(function()
				handlePlayer(player)
			end)
		end

		return maid
	end) :: any
end

--[=[
	Observes the first time the character appearance is loaded

	@param player Player
	@return Observable<()>
]=]
function RxPlayerUtils.observeFirstAppearanceLoaded(player: Player): Observable.Observable<()>
	assert(typeof(player) == "Instance", "Bad player")

	return Observable.new(function(sub)
		if player:HasAppearanceLoaded() then
			sub:Fire()
			sub:Complete()
			return
		end

		local maid = Maid.new()

		-- In case this works
		maid:GiveTask(player.CharacterAppearanceLoaded:Connect(function()
			sub:Fire()
			sub:Complete()
		end))

		maid:GiveTask(task.spawn(function()
			while not player:HasAppearanceLoaded() and player:IsDescendantOf(game) do
				task.wait(0.05)
			end

			if player:HasAppearanceLoaded() then
				sub:Fire()
				sub:Complete()
			else
				sub:Fail("Failed to load appearance before player left the game")
			end
		end))

		return maid
	end)
end

return RxPlayerUtils
