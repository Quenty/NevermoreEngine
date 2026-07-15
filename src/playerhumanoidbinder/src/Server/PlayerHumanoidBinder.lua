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
		end
	end
end

function PlayerHumanoidBinder._handlePlayerAdded<T>(
	self: PlayerHumanoidBinder<T>,
	playerMaid: Maid.Maid,
	player: Player
): ()
	local maid = Maid.new()

	-- TODO: Use HumanoidTrackerService
	maid:GiveTask(self._humanoidTrackerService:ObserveHumanoid(player):Subscribe(function(humanoid)
		if humanoid then
			self:Bind(humanoid)
		end
	end))

	playerMaid[player] = maid
end

return PlayerHumanoidBinder
