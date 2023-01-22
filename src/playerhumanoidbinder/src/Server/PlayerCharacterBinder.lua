--[=[
	Binder that will automatically bind to each player's character
	@class PlayerCharacterBinder
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Binder = require("Binder")
local Maid = require("Maid")

local PlayerCharacterBinder = setmetatable({}, Binder)
PlayerCharacterBinder.ClassName = "PlayerCharacterBinder"
PlayerCharacterBinder.__index = PlayerCharacterBinder

--[=[
	Returns a new PlayerCharacterBinder
	@param tag string
	@param class BinderContructor
	@param ... any
	@return PlayerCharacterBinder<T>
]=]
function PlayerCharacterBinder.new(tag, class, ...)
	local self = setmetatable(Binder.new(tag, class, ...), PlayerCharacterBinder)

	self._shouldTag = Instance.new("BoolValue")
	self._shouldTag.Value = true
	self._maid:GiveTask(self._shouldTag)

	return self
end

--[=[
	Sets whether tagging should be enabled
	@param shouldTag boolean
]=]
function PlayerCharacterBinder:SetAutomaticTagging(shouldTag)
	assert(type(shouldTag) == "boolean", "Bad shouldTag")
	assert(self._shouldTag, "Missing self._shouldTag")

	self._shouldTag.Value = shouldTag
end

--[=[
	Starts the binder. See [Binder.Start].
	Should be done via a [ServiceBag].
]=]
function PlayerCharacterBinder:Start()
	local results = { getmetatable(PlayerCharacterBinder).Start(self) }

	self._maid:GiveTask(self._shouldTag.Changed:Connect(function()
		self:_bindTagging(true)
	end))
	self:_bindTagging()

	return unpack(results)
end

function PlayerCharacterBinder:_bindTagging(doUnbinding)
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

		for _, player in pairs(Players:GetPlayers()) do
			self:_handlePlayerAdded(playerMaid, player)
		end

		self._maid._tagging = maid
	else
		self._maid._tagging = nil

		if doUnbinding then
			for _, player in pairs(Players:GetPlayers()) do
				local character = player.Character
				if character then
					self:Unbind(character)
				end
			end
		end
	end
end

function PlayerCharacterBinder:_handlePlayerAdded(playerMaid, player)
	local maid = Maid.new()

	maid:GiveTask(player.CharacterAdded:Connect(function(character)
		self:Bind(character)
	end))

	if player.Character then
		self:Bind(player.Character)
	end

	playerMaid[player] = maid
end


return PlayerCharacterBinder