--!strict
--[=[
	Tracks hold state for an input. Handles the timing logic
	and exposes observables for hold progress.

	```lua
	local holdableInputModel = HoldableInputModel.new()
	holdableInputModel:SetMaxHoldDuration(1.5)

	maid:GiveTask(holdableInputModel.HoldReleased:Connect(function(holdPercent)
		print("Released at", holdPercent)
	end))

	-- When input begins
	holdableInputModel:StartHold()

	-- When input ends
	holdableInputModel:StopHold()
	```

	@class HoldableInputModel
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local Observable = require("Observable")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local HoldableInputModel = setmetatable({}, BaseObject)
HoldableInputModel.ClassName = "HoldableInputModel"
HoldableInputModel.__index = HoldableInputModel

export type HoldableInputModel = typeof(setmetatable(
	{} :: {
		_maxHoldDuration: ValueObject.ValueObject<number>,
		_holdPercent: ValueObject.ValueObject<number>,
		_isHolding: ValueObject.ValueObject<boolean>,
		HoldStarted: Signal.Signal<()>,
		HoldUpdated: Signal.Signal<number>,
		HoldReleased: Signal.Signal<number>,
	},
	{} :: typeof({ __index = HoldableInputModel })
)) & BaseObject.BaseObject

--[=[
	Constructs a new HoldableInputModel

	@return HoldableInputModel
]=]
function HoldableInputModel.new(): HoldableInputModel
	local self = setmetatable(BaseObject.new() :: any, HoldableInputModel)

	self._maxHoldDuration = self._maid:Add(ValueObject.new(1, "number"))
	self._holdPercent = self._maid:Add(ValueObject.new(0, "number"))
	self._isHolding = self._maid:Add(ValueObject.new(false, "boolean"))

	--[=[
		Fires when a hold begins
		@prop HoldStarted Signal<>
		@within HoldableInputModel
	]=]
	self.HoldStarted = self._maid:Add(Signal.new())

	--[=[
		Fires when the hold percent updates
		@prop HoldUpdated Signal<number>
		@within HoldableInputModel
	]=]
	self.HoldUpdated = self._maid:Add(Signal.new())

	--[=[
		Fires when a hold is released with the final hold percent
		@prop HoldReleased Signal<number>
		@within HoldableInputModel
	]=]
	self.HoldReleased = self._maid:Add(Signal.new())

	return self
end

--[=[
	Sets the maximum hold duration in seconds

	@param duration number | Observable<number>
	@return MaidTask
]=]
function HoldableInputModel.SetMaxHoldDuration(self: HoldableInputModel, duration: number | Observable.Observable<number>)
	return self._maxHoldDuration:Mount(duration)
end

--[=[
	Gets the maximum hold duration

	@return number
]=]
function HoldableInputModel.GetMaxHoldDuration(self: HoldableInputModel): number
	return self._maxHoldDuration.Value
end

--[=[
	Observes the maximum hold duration

	@return Observable<number>
]=]
function HoldableInputModel.ObserveMaxHoldDuration(self: HoldableInputModel): Observable.Observable<number>
	return self._maxHoldDuration:Observe()
end

--[=[
	Observes the current hold percent (0-1)

	@return Observable<number>
]=]
function HoldableInputModel.ObserveHoldPercent(self: HoldableInputModel): Observable.Observable<number>
	return self._holdPercent:Observe()
end

--[=[
	Gets the current hold percent (0-1)

	@return number
]=]
function HoldableInputModel.GetHoldPercent(self: HoldableInputModel): number
	return self._holdPercent.Value
end

--[=[
	Observes whether currently holding

	@return Observable<boolean>
]=]
function HoldableInputModel.ObserveIsHolding(self: HoldableInputModel): Observable.Observable<boolean>
	return self._isHolding:Observe()
end

--[=[
	Returns whether currently holding

	@return boolean
]=]
function HoldableInputModel.IsHolding(self: HoldableInputModel): boolean
	return self._isHolding.Value
end

--[=[
	Starts tracking a hold. Call this when input begins.
]=]
function HoldableInputModel.StartHold(self: HoldableInputModel): ()
	self._maid._holdMaid = nil

	local maid = Maid.new()
	local elapsed = 0
	local maxDuration = self._maxHoldDuration.Value or 1

	self._isHolding.Value = true
	self._holdPercent.Value = 0
	self.HoldStarted:Fire()

	maid:GiveTask(RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local newPercent = math.clamp(elapsed / maxDuration, 0, 1)
		if self._holdPercent.Value ~= newPercent then
			self._holdPercent.Value = newPercent
			self.HoldUpdated:Fire(newPercent)
		end
	end))

	maid:GiveTask(function()
		local finalPercent = self._holdPercent.Value
		self._holdPercent.Value = 0
		self._isHolding.Value = false
		self.HoldReleased:Fire(finalPercent)
	end)

	self._maid._holdMaid = maid
end

--[=[
	Stops tracking a hold and fires HoldReleased with the final percent.
	Call this when input ends.
]=]
function HoldableInputModel.StopHold(self: HoldableInputModel): ()
	self._maid._holdMaid = nil
end

--[=[
	Cancels a hold without firing HoldReleased.
	Use this when the hold should be aborted (e.g., interrupted by stun).
]=]
function HoldableInputModel.CancelHold(self: HoldableInputModel): ()
	if self._maid._holdMaid then
		self._isHolding.Value = false
		self._holdPercent.Value = 0
		-- Clear without triggering cleanup function
		local holdMaid = self._maid._holdMaid
		self._maid._holdMaid = nil
		if holdMaid and holdMaid.Destroy then
			-- Destroy without the cleanup function firing HoldReleased
			holdMaid._tasks = {}
			holdMaid:Destroy()
		end
	end
end

return HoldableInputModel
