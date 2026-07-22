--!strict
--[=[
	Binds the given class to each player in the game
	@class PlayerBinder
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Binder = require("Binder")
local PlayerMockService = require("PlayerMockService")

local PlayerBinder = setmetatable({}, Binder)
PlayerBinder.ClassName = "PlayerBinder"
PlayerBinder.__index = PlayerBinder

export type PlayerBinder<T> = typeof(setmetatable({} :: {}, {} :: typeof({ __index = PlayerBinder }))) & Binder.Binder<T>

--[=[
	Returns a new PlayerBinder
	@param tag string
	@param class BinderContructor
	@param ... any
	@return PlayerBinder<T>
]=]
function PlayerBinder.new<T>(tag: string, class: Binder.BinderConstructor<T>, ...: any): PlayerBinder<T>
	local self: PlayerBinder<T> = setmetatable(Binder.new(tag, class, ...) :: any, PlayerBinder)

	return self
end

--[=[
	Initializes the binder. Captures the owning [ServiceBag] so [PlayerBinder.Start] can discover mock
	players from it. Done via a ServiceBag.
]=]
function PlayerBinder.Init<T>(self: PlayerBinder<T>, serviceBag: any, ...: any): ...any
	-- The ServiceBag passes itself as the first Init arg (and on to bound-class constructors).
	(self :: any)._serviceBag = serviceBag

	if serviceBag then
		-- Declare the PlayerMockService dependency during the init phase. A test can then
		-- serviceBag:GetService(PlayerMockService) after the bag has started (a bag refuses to add
		-- new services once started), and every service upstream of a PlayerBinder inherits this.
		serviceBag:GetService(PlayerMockService)
	end

	return (getmetatable(PlayerBinder) :: any).Init(self, serviceBag, ...)
end

--[=[
	Starts the binder. See [Binder.Start].
	Should be done via a [ServiceBag].
]=]
function PlayerBinder.Start<T>(self: PlayerBinder<T>): ...any
	local results = { (getmetatable(PlayerBinder) :: any).Start(self) }

	self._maid:GiveTask(Players.PlayerAdded:Connect(function(player)
		self:Tag(player)
	end))
	for _, item in Players:GetPlayers() do
		self:Tag(item)
	end

	-- Discover mock players the same way as real joins. Replication is the default and place-wide,
	-- like Players:GetPlayers() -- any parented mock binds here, whichever bag (either realm) made
	-- it; production places just carry no mocks (they are only ever created by tests).
	local serviceBag = (self :: any)._serviceBag
	if serviceBag then
		self._maid:GiveTask(serviceBag:GetService(PlayerMockService):ObservePlayerMocks(function(playerMock)
			self:Tag(playerMock)
		end))
	end

	return unpack(results)
end

return PlayerBinder
