--!strict
--[=[
	Binder that will automatically bind to each player's character
	@class PlayerCharacterBinder
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Binder = require("Binder")
local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerMock = require("PlayerMock")
local PlayerMockService = require("PlayerMockService")
local Rx = require("Rx")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local PlayerCharacterBinder = setmetatable({}, Binder)
PlayerCharacterBinder.ClassName = "PlayerCharacterBinder"
PlayerCharacterBinder.__index = PlayerCharacterBinder

export type PlayerCharacterBinder<T> =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag?,
			_shouldTag: ValueObject.ValueObject<boolean>,
		},
		{} :: typeof({ __index = PlayerCharacterBinder })
	))
	& Binder.Binder<T>

--[=[
	Returns a new PlayerCharacterBinder
	@param tag string
	@param class BinderContructor
	@param ... any
	@return PlayerCharacterBinder<T>
]=]
function PlayerCharacterBinder.new<T>(tag: string, class: Binder.BinderConstructor<T>, ...): PlayerCharacterBinder<T>
	local self: PlayerCharacterBinder<T> = setmetatable(Binder.new(tag, class, ...) :: any, PlayerCharacterBinder)

	return self
end

--[=[
	Inits the binder. See [Binder.Init].
	Should be done via a [ServiceBag].

	@param serviceBag ServiceBag
	@param ... any
]=]
function PlayerCharacterBinder.Init<T>(self: PlayerCharacterBinder<T>, serviceBag: ServiceBag.ServiceBag?, ...): ()
	self._serviceBag = serviceBag

	if serviceBag then
		-- Declare the PlayerMockService dependency during the init phase (a ServiceBag refuses to add
		-- new services once started). Production bags just carry an empty registry -- mocks are only
		-- ever created by tests -- so this adds no production behavior.
		serviceBag:GetService(PlayerMockService)
	end

	getmetatable(PlayerCharacterBinder).Init(self, serviceBag, ...)

	if not self._shouldTag then
		self._shouldTag = self._maid:Add(ValueObject.new(true, "boolean"))
	end
end

--[=[
	Sets whether tagging should be enabled
	@param shouldTag boolean
]=]
function PlayerCharacterBinder.SetAutomaticTagging<T>(self: PlayerCharacterBinder<T>, shouldTag: boolean): ()
	assert(type(shouldTag) == "boolean", "Bad shouldTag")
	assert(self._shouldTag, "Missing self._shouldTag")

	self._shouldTag.Value = shouldTag
end

--[=[
	@return Observable<boolean>
]=]
function PlayerCharacterBinder.ObserveAutomaticTagging<T>(self: PlayerCharacterBinder<T>): Observable.Observable<boolean>
	return self._shouldTag:Observe()
end

--[=[
	@param predicate function -- Optional predicate
	@return Observable<Brio<boolean>>
]=]
function PlayerCharacterBinder.ObserveAutomaticTaggingBrio<T>(
	self: PlayerCharacterBinder<T>,
	predicate: Rx.Predicate<boolean>?
): Observable.Observable<Brio.Brio<boolean>>
	return self._shouldTag:ObserveBrio(predicate)
end

--[=[
	Starts the binder. See [Binder.Start].
	Should be done via a [ServiceBag].
]=]
function PlayerCharacterBinder.Start<T>(self: PlayerCharacterBinder<T>): ...any
	local results = { getmetatable(PlayerCharacterBinder).Start(self) }

	self._maid:GiveTask(self._shouldTag.Changed:Connect(function()
		self:_bindTagging(true)
	end))
	self:_bindTagging()

	return unpack(results)
end

function PlayerCharacterBinder._bindTagging<T>(self: PlayerCharacterBinder<T>, doUnbinding: boolean?): ()
	if self._shouldTag.Value then
		local maid = Maid.new()

		local playerMaid = Maid.new()
		maid:GiveTask(playerMaid)

		maid:GiveTask(Players.PlayerAdded:Connect(function(player)
			self:_handlePlayerAdded(playerMaid, player)
		end))
		maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
			playerMaid[player] = nil
		end))

		for _, player in Players:GetPlayers() do
			self:_handlePlayerAdded(playerMaid, player)
		end

		-- Discover replicated PlayerMocks the same way as real joins. Production places just carry an
		-- empty replicated set, so this adds no production behavior.
		if self._serviceBag then
			-- Cast: the service's instance fields are assigned in Init, so its methods do not
			-- type-check against the exported module type.
			local playerMockService: any = self._serviceBag:GetService(PlayerMockService)
			maid:GiveTask(playerMockService:ObservePlayerMocks(function(playerMock)
				self:_handlePlayerAdded(playerMaid, playerMock)
			end))
		end

		self._maid._tagging = maid
	else
		self._maid._tagging = nil

		if doUnbinding then
			for _, player in Players:GetPlayers() do
				local character = player.Character
				if character then
					self:Unbind(character)
				end
			end

			if self._serviceBag then
				local playerMockService: any = self._serviceBag:GetService(PlayerMockService)
				for _, playerMock in playerMockService:GetPlayerMocks() do
					local character = PlayerMock.read(playerMock, "Character")
					if character then
						self:Unbind(character)
					end
				end
			end
		end
	end
end

function PlayerCharacterBinder._handlePlayerAdded<T>(
	self: PlayerCharacterBinder<T>,
	playerMaid: Maid.Maid,
	player: Player
): ()
	local maid = Maid.new()

	if PlayerMock.isMock(player) then
		-- Mirror the real branch below through the mock's stand-ins: CharacterAdded fires via
		-- PlayerMock.loadCharacterAsync (a bare Character write deliberately does not fire it, like
		-- the engine), and Destroying stands in for PlayerRemoving.
		maid:GiveTask(PlayerMock.getSignal(player, "CharacterAdded"):Connect(function(character)
			self:Tag(character)
		end))
		maid:GiveTask(player.Destroying:Connect(function()
			playerMaid[player] = nil
		end))

		local character = PlayerMock.read(player, "Character")
		if character then
			self:Tag(character)
		end
	else
		maid:GiveTask(player.CharacterAdded:Connect(function(character)
			self:Tag(character)
		end))

		if player.Character then
			self:Tag(player.Character)
		end
	end

	playerMaid[player] = maid
end

return PlayerCharacterBinder
