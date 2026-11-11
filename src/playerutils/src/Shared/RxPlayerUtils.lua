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
local PlayerMock = require("PlayerMock")
local PlayerMockUtils = require("PlayerMockUtils")
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

		local function handleRemoving(player: Player)
			maid[player] = nil
		end

		maid:GiveTask(Players.PlayerAdded:Connect(handlePlayer))
		maid:GiveTask(Players.PlayerRemoving:Connect(handleRemoving))

		-- Mocks are invisible to the Players service, so their tag lifecycle is the counterpart of
		-- the join events, feeding the same handlers.
		maid:GiveTask(PlayerMock.getMockAddedSignal():Connect(handlePlayer))
		maid:GiveTask(PlayerMock.getMockRemovingSignal():Connect(handleRemoving))

		for _, player in Players:GetPlayers() do
			task.spawn(function()
				handlePlayer(player)
			end)
		end

		for _, player in PlayerMock.getMocks() do
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
		end) :: any,
	}) :: any
end

--[=[
	Observes the character model for the player
]=]
function RxPlayerUtils.observeHumanoidsBrio(): Observable.Observable<Brio.Brio<Humanoid>>
	return RxPlayerUtils.observePlayersBrio():Pipe({
		RxBrioUtils.flatMapBrio(function(player)
			return RxCharacterUtils.observeLastHumanoidBrio(player)
		end) :: any,
	}) :: any
end

--[=[
	Observes the current local player

	@return Observable<Brio<Player>>
]=]
function RxPlayerUtils.observeLocalPlayerBrio(): Observable.Observable<Brio.Brio<Player>>
	-- Headless tests have no Players.LocalPlayer; a test designates a PlayerMock instead. Observed
	-- rather than read once, so a designation made after subscribing still resolves.
	return Rx.combineLatest({
		real = RxInstanceUtils.observeProperty(Players, "LocalPlayer"),
		mocked = PlayerMockUtils.observeMockedLocalPlayer(),
	}):Pipe({
		Rx.map(function(state: any): Player?
			return state.real or state.mocked
		end) :: any,
		Rx.distinct() :: any,
		RxBrioUtils.switchToBrio(function(player)
			return player ~= nil
		end) :: any,
	}) :: any
end

--[=[
	Observes the current local player's humanoid
]=]
function RxPlayerUtils.observeLocalPlayerHumanoidBrio(): Observable.Observable<Brio.Brio<Player>>
	return RxPlayerUtils.observeLocalPlayerBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(player)
			return RxCharacterUtils.observeLastHumanoidBrio(player)
		end) :: any,
	}) :: any
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
		maid:GiveTask(PlayerMock.getMockAddedSignal():Connect(handlePlayer))

		for _, player in Players:GetPlayers() do
			task.spawn(function()
				handlePlayer(player)
			end)
		end

		for _, player in PlayerMock.getMocks() do
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

	local isMock = PlayerMock.isMock(player)

	return Observable.new(function(sub)
		local alreadyLoaded = if isMock
			then PlayerMock.read(player, "HasAppearanceLoaded")
			else player:HasAppearanceLoaded()
		if alreadyLoaded then
			sub:Fire()
			sub:Complete()
			return
		end

		local maid = Maid.new()

		local characterAppearanceLoaded: RBXScriptSignal<...any> = if isMock
			then PlayerMock.getSignal(player, "CharacterAppearanceLoaded")
			else player.CharacterAppearanceLoaded

		-- In case this works
		maid:GiveTask(characterAppearanceLoaded:Connect(function()
			sub:Fire()
			sub:Complete()
		end))

		maid:GiveTask(task.spawn(function()
			local loaded = false
			while not loaded and player:IsDescendantOf(game) do
				task.wait(0.05)
				loaded = if isMock then PlayerMock.read(player, "HasAppearanceLoaded") else player:HasAppearanceLoaded()
			end

			if loaded then
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
