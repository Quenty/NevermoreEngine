--- Binds the given class to each player in the game
-- @classmod PlayerBinder

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Binder = require("Binder")

local PlayerBinder = setmetatable({}, Binder)
PlayerBinder.ClassName = "PlayerBinder"
PlayerBinder.__index = PlayerBinder

function PlayerBinder.new(tag, class, ...)
	local self = setmetatable(Binder.new(tag, class, ...), PlayerBinder)

	return self
end

function PlayerBinder:Start()
	local results = { getmetatable(PlayerBinder).Start(self) }

	self._maid:GiveTask(Players.PlayerAdded:Connect(function(player)
		self:Bind(player)
	end))
	for _, item in pairs(Players:GetPlayers()) do
		self:Bind(item)
	end

	return unpack(results)
end

return PlayerBinder