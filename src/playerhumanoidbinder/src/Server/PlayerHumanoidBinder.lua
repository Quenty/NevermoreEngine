--!strict
--[=[
	Binder that will automatically bind to each player's humanoid
	@class PlayerHumanoidBinder
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Binder = require("Binder")
local HumanoidTrackerService = require("HumanoidTrackerService")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PlayerMockService = require("PlayerMockService")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local PlayerHumanoidBinder = setmetatable({}, Binder)
PlayerHumanoidBinder.ClassName = "PlayerHumanoidBinder"
PlayerHumanoidBinder.__index = PlayerHumanoidBinder

export type PlayerHumanoidBinder<T> =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_humanoidTrackerService: any,
			_shouldTag: ValueObject.ValueObject<boolean>,
		},
		{} :: typeof({ __index = PlayerHumanoidBinder })
	))
	& Binder.Binder<T>

--[=[
	Returns a new PlayerHumanoidBinder
	@param tag string
	@param class BinderContructor
	@param ... any
	@return PlayerHumanoidBinder<T>
]=]
function PlayerHumanoidBinder.new<T>(tag: string, class: Binder.BinderConstructor<T>, ...): PlayerHumanoidBinder<T>
	local self: PlayerHumanoidBinder<T> = setmetatable(Binder.new(tag, class, ...) :: any, PlayerHumanoidBinder)

	return self
end

--[=[
	Inits the binder. See [Binder.Init].
	Should be done via a [ServiceBag].

	@param serviceBag ServiceBag
	@param ... any
]=]
function PlayerHumanoidBinder.Init<T>(self: PlayerHumanoidBinder<T>, serviceBag: ServiceBag.ServiceBag, ...): ()
	self._serviceBag = assert(serviceBag, "No serviceBag")

	getmetatable(PlayerHumanoidBinder).Init(self, serviceBag, ...)

	self._humanoidTrackerService = self._serviceBag:GetService(HumanoidTrackerService)

	-- Declare the PlayerMockService dependency during the init phase (a ServiceBag refuses to add new
	-- services once started). Production bags just carry an empty registry -- mocks are only ever
	-- created by tests -- so this adds no production behavior.
	self._serviceBag:GetService(PlayerMockService)

	if not self._shouldTag then
		self._shouldTag = self._maid:Add(ValueObject.new(true, "boolean"))
	end
end

--[=[
	Sets whether tagging should be enabled
	@param shouldTag boolean
]=]
function PlayerHumanoidBinder.SetAutomaticTagging<T>(self: PlayerHumanoidBinder<T>, shouldTag: boolean): ()
	assert(type(shouldTag) == "boolean", "Bad shouldTag")
	assert(self._shouldTag, "Missing self._shouldTag")

	self._shouldTag.Value = shouldTag
end

--[=[
	@return Observable<boolean>
]=]
function PlayerHumanoidBinder.ObserveAutomaticTagging<T>(self: PlayerHumanoidBinder<T>)
	return self._shouldTag:Observe()
end

--[=[
	@param predicate function -- Optional predicate
	@return Observable<Brio<boolean>>
]=]
function PlayerHumanoidBinder.ObserveAutomaticTaggingBrio<T>(
	self: PlayerHumanoidBinder<T>,
	predicate: ((boolean) -> boolean)?
)
	return self._shouldTag:ObserveBrio(predicate)
end

--[=[
	Starts the binder. See [Binder.Start].
	Should be done via a [ServiceBag].
]=]
function PlayerHumanoidBinder.Start<T>(self: PlayerHumanoidBinder<T>)
	local results = { getmetatable(PlayerHumanoidBinder).Start(self) }

	self._maid:GiveTask(self._shouldTag.Changed:Connect(function()
		self:_bindTagging(true)
	end))
	self:_bindTagging()

	return unpack(results)
end

function PlayerHumanoidBinder._bindTagging<T>(self: PlayerHumanoidBinder<T>, doUnbinding: boolean?): ()
	if self._shouldTag.Value then
		local maid = Maid.new()

		local playerMaid = maid:Add(Maid.new())

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
				local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
				if humanoid then
					self:Unbind(humanoid)
				end
			end

			if self._serviceBag then
				local playerMockService: any = self._serviceBag:GetService(PlayerMockService)
				for _, playerMock in playerMockService:GetPlayerMocks() do
					local character = PlayerMock.read(playerMock, "Character")
					local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
					if humanoid then
						self:Unbind(humanoid)
					end
				end
			end
		end
	end
end

function PlayerHumanoidBinder._handlePlayerAdded<T>(
	self: PlayerHumanoidBinder<T>,
	playerMaid: Maid.Maid,
	player: Player
): ()
	local maid = Maid.new()

	maid:GiveTask(self._humanoidTrackerService:ObserveHumanoid(player):Subscribe(function(humanoid)
		if humanoid then
			self:Bind(humanoid)
		end
	end))

	-- Destroying stands in for PlayerRemoving on a PlayerMock.
	if PlayerMock.isMock(player) then
		maid:GiveTask(player.Destroying:Connect(function()
			playerMaid[player] = nil
		end))
	end

	playerMaid[player] = maid
end

return PlayerHumanoidBinder
