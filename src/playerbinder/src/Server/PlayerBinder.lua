--!strict
--[=[
	Binds the given class to each player in the game
	@class PlayerBinder
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Binder = require("Binder")

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

	return unpack(results)
end

return PlayerBinder
