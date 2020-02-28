--- Tracks a player's character's humanoid
-- @classmod HumanoidTracker

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local fastSpawn = require("fastSpawn")
local Maid = require("Maid")
local Signal = require("Signal")
local ValueObject = require("ValueObject")
local Promise = require("Promise")

local HumanoidTracker = {}
HumanoidTracker.ClassName = "HumanoidTracker"
HumanoidTracker.__index = HumanoidTracker

function HumanoidTracker.new(player)
	local self = setmetatable({}, HumanoidTracker)

	self._player = player or error("No player")
	self._maid = Maid.new()

	--- Tracks the current character humanoid, may be nil
	self.Humanoid = ValueObject.new()
	self._maid:GiveTask(self.Humanoid)

	--- Tracks the alive humanoid, may be nil
	self.AliveHumanoid = ValueObject.new()
	self._maid:GiveTask(self.AliveHumanoid)

	self._maid:GiveTask(self.Humanoid.Changed:Connect(function(newHumanoid, oldHumanoid, maid)
		self:_handleHumanoidChanged(newHumanoid, oldHumanoid, maid)
	end))

	self._maid:GiveTask(self._player.CharacterAdded:Connect(function(character)
		self:_handleCharacter(character)
	end))

	if self._player.Character then
		fastSpawn(self._handleCharacter, self, self._player.Character)
	end

	self.HumanoidDied = Signal.new()
	self._maid:GiveTask(self.HumanoidDied)

	return self
end

function HumanoidTracker:PromiseNextHumanoid()
	if self.Humanoid.Value then
		return Promise.resolved(self.Humanoid.Value)
	end

	if self._maid._nextHumanoidPromise then
		return self._maid._nextHumanoidPromise
	end

	local promise = Promise.new()

	local conn = self.Humanoid.Changed:Connect(function(newValue)
		if newValue then
			promise:Resolve(newValue)
		end
	end)

	promise:Finally(function()
		conn:Disconnect()
	end)

	self._maid._nextHumanoidPromise = promise

	return promise
end

function HumanoidTracker:_handleCharacter(character)
	local maid = Maid.new()
	self._maid._characterMaid = maid

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self.Humanoid.Value = humanoid
		return
	end

	self.Humanoid.Value = nil

	-- Listen for changes
	maid._childAdded = character.ChildAdded:Connect(function(child)
		if child:IsA("Humanoid") then
			maid._childAdded = nil
			self.Humanoid.Value = child
		end
	end)
end

function HumanoidTracker:_handleHumanoidChanged(newHumanoid, oldHumanoid, maid)
	if not newHumanoid then
		self.AliveHumanoid.Value = nil
		return
	end

	if newHumanoid.Health <= 0 then
		self.AliveHumanoid.Value = nil
		return
	end

	self.AliveHumanoid.Value = newHumanoid

	maid:GiveTask(newHumanoid.Died:Connect(function()
		self.AliveHumanoid.Value = nil

		-- AliveHumanoid changing may proc .Destroy method
		if self.Destroy then
			self.HumanoidDied:Fire(newHumanoid)
		end
	end))
end

function HumanoidTracker:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return HumanoidTracker