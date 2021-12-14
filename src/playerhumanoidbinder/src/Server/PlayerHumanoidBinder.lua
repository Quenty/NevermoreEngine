--- Binder that will automatically bind to each player's humanoid
-- @classmod PlayerHumanoidBinder
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Binder = require("Binder")
local Maid = require("Maid")
local HumanoidTracker = require("HumanoidTracker")

local PlayerHumanoidBinder = setmetatable({}, Binder)
PlayerHumanoidBinder.ClassName = "PlayerHumanoidBinder"
PlayerHumanoidBinder.__index = PlayerHumanoidBinder

function PlayerHumanoidBinder.new(tag, class, ...)
	local self = setmetatable(Binder.new(tag, class, ...), PlayerHumanoidBinder)

	self._maid = Maid.new()
	self._maid:GiveTask(self._maid)

	self._shouldTag = Instance.new("BoolValue")
	self._shouldTag.Value = true
	self._maid:GiveTask(self._shouldTag)

	return self
end

function PlayerHumanoidBinder:SetAutomaticTagging(shouldTag)
	assert(type(shouldTag) == "boolean", "Bad shouldTag")
	assert(self._shouldTag, "Missing self._shouldTag")

	self._shouldTag.Value = shouldTag
end

function PlayerHumanoidBinder:Start()
	local results = { getmetatable(PlayerHumanoidBinder).Start(self) }

	self._maid:GiveTask(self._shouldTag.Changed:Connect(function()
		self:_bindTagging(true)
	end))
	self:_bindTagging()

	return unpack(results)
end

function PlayerHumanoidBinder:_bindTagging(doUnbinding)
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
				local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
				if humanoid then
					self:Unbind(humanoid)
				end
			end
		end
	end
end

function PlayerHumanoidBinder:_handlePlayerAdded(playerMaid, player)
	local maid = Maid.new()

	-- TODO: Use HumanoidTrackerService
	local tracker = HumanoidTracker.new(player)
	maid:GiveTask(tracker)

	local function handleHumanoid(newHumanoid)
		if newHumanoid then
			self:Bind(newHumanoid)
		end
	end

	maid:GiveTask(tracker.Humanoid.Changed:Connect(handleHumanoid))

	-- Bind humanoid
	handleHumanoid(tracker.Humanoid.Value)

	playerMaid[player] = maid
end


return PlayerHumanoidBinder