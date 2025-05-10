--!strict
--[=[
	Tracks a player's character's humanoid
	@class HumanoidTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local Promise = require("Promise")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local HumanoidTracker = setmetatable({}, BaseObject)
HumanoidTracker.ClassName = "HumanoidTracker"
HumanoidTracker.__index = HumanoidTracker

export type HumanoidTracker = typeof(setmetatable(
	{} :: {
		_player: Player,

		--[=[
			Fires when the humanoid dies
			@prop HumanoidDied Signal<Humanoid>
			@within HumanoidTracker
		]=]
		HumanoidDied: Signal.Signal<Humanoid?>,

		--[=[
			Current humanoid which is alive
			@prop AliveHumanoid ValueObject<Humanoid>
			@within HumanoidTracker
		]=]
		AliveHumanoid: ValueObject.ValueObject<Humanoid?>,

		--[=[
			Current humanoid
			@prop Humanoid ValueObject<Humanoid>
			@within HumanoidTracker
		]=]
		Humanoid: ValueObject.ValueObject<Humanoid?>,
	},
	{ __index = HumanoidTracker }
)) & BaseObject.BaseObject

--[=[
	Tracks the player's current humanoid

	:::tip
	Be sure to clean up the tracker once you're done!
	:::
	@param player Player
	@return HumanoidTracker
]=]
function HumanoidTracker.new(player: Player): HumanoidTracker
	local self = setmetatable(BaseObject.new() :: any, HumanoidTracker)

	self._player = player or error("No player")

	self.HumanoidDied = self._maid:Add(Signal.new())

	-- Tracks the current character humanoid, may be nil
	self.Humanoid = self._maid:Add(ValueObject.new())

	-- Tracks the alive humanoid, may be nil
	self.AliveHumanoid = self._maid:Add(ValueObject.new())

	self._maid:GiveTask(self.Humanoid.Changed:Connect(function(newHumanoid, oldHumanoid)
		local maid = Maid.new()

		if not self.Destroy then
			return
		end
		self:_handleHumanoidChanged(newHumanoid, oldHumanoid, maid)

		self._maid._current = maid
	end))

	self._maid:GiveTask(self._player:GetPropertyChangedSignal("Character"):Connect(function()
		if not self.Destroy then
			return
		end
		self:_onCharacterChanged()
	end))

	self:_onCharacterChanged()

	return self
end

--[=[
	Returns a promise that resolves when the next humanoid is found.
	If a humanoid is already there, then returns a resolved promise
	with that humanoid.

	@return Promise<Humanoid>
]=]
function HumanoidTracker.PromiseNextHumanoid(self: HumanoidTracker): Promise.Promise<Humanoid>
	if self.Humanoid.Value then
		return Promise.resolved(self.Humanoid.Value)
	end

	if self._maid._nextHumanoidPromise then
		return self._maid._nextHumanoidPromise :: Promise.Promise<Humanoid>
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

function HumanoidTracker._onCharacterChanged(self: HumanoidTracker)
	local maid = Maid.new()
	self._maid._characterMaid = maid

	local character = self._player.Character
	if not character then
		self.Humanoid.Value = nil
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self.Humanoid.Value = humanoid -- TODO: Track if this humanoid goes away
		return
	end

	self.Humanoid.Value = nil

	-- Listen for changes
	maid._childAdded = character.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Humanoid") then
			maid._childAdded = nil
			self.Humanoid.Value = child -- TODO: Track if this humanoid goes away
		end
	end)
end

function HumanoidTracker._handleHumanoidChanged(self: HumanoidTracker, newHumanoid: Humanoid, _, maid: Maid.Maid)
	if not newHumanoid then
		self.AliveHumanoid.Value = nil
		return
	end

	if newHumanoid.Health <= 0 then
		self.AliveHumanoid.Value = nil
		return
	end

	self.AliveHumanoid.Value = newHumanoid

	local alive = true
	maid:GiveTask(function()
		alive = false
	end)
	maid:GiveTask(newHumanoid.Died:Connect(function()
		if not alive then
			return
		end

		self.AliveHumanoid.Value = nil

		-- AliveHumanoid changing may proc .Destroy method
		if self.Destroy then
			self.HumanoidDied:Fire(newHumanoid)
		end
	end))
end

return HumanoidTracker
