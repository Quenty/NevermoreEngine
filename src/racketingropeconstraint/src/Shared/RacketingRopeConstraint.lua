--[=[
	Tries to racket a rope constraint back down to a reasonable length. Use [RopeConstraint.WinchEnabled]
	@class RacketingRopeConstraint
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local OverriddenProperty = require("OverriddenProperty")
local Promise = require("Promise")
local RacketingRopeConstraintInterface = require("RacketingRopeConstraintInterface")
local ValueObject = require("ValueObject")
local TieRealmService = require("TieRealmService")

local START_DISTANCE = 1000

local RacketingRopeConstraint = setmetatable({}, BaseObject)
RacketingRopeConstraint.ClassName = "RacketingRopeConstraint"
RacketingRopeConstraint.__index = RacketingRopeConstraint

function RacketingRopeConstraint.new(ropeConstraint, serviceBag)
	local self = setmetatable(BaseObject.new(ropeConstraint), RacketingRopeConstraint)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._tieRealmService = self._serviceBag:GetService(TieRealmService)

	self._smallestDistance = START_DISTANCE
	self._targetDistance = 0.5

	self._isConstrained = self._maid:Add(ValueObject.new(false, "boolean"))

	self._maid:GiveTask(self._obj:GetPropertyChangedSignal("Enabled"):Connect(function()
		self:_handleActiveChanged()
	end))
	self._maid:GiveTask(self._obj:GetPropertyChangedSignal("Attachment0"):Connect(function()
		self:_handleActiveChanged()
	end))
	self._maid:GiveTask(self._obj:GetPropertyChangedSignal("Attachment1"):Connect(function()
		self:_handleActiveChanged()
	end))

	self:_handleActiveChanged()

	if not RunService:IsServer() then
		self._overriddenLength = self._maid:Add(OverriddenProperty.new(self._obj, "Length"))
	end

	self._maid:GiveTask(RacketingRopeConstraintInterface:Implement(self._obj, self, self._tieRealmService:GetTieRealm()))

	return self
end

function RacketingRopeConstraint:PromiseConstrained()
	if self:_isValid() and self:_queryIsConstrained() then
		return Promise.resolved()
	end

	if self._maid._pendingConstrainedPromise then
		return self._maid._pendingConstrainedPromise
	end

	local promise = Promise.new()
	self._maid._pendingConstrainedPromise = promise
	return promise
end

function RacketingRopeConstraint:ObserveIsConstrained()
	return self._isConstrained:Observe()
end

function RacketingRopeConstraint:_queryIsConstrained()
	return self._obj.Length <= self._targetDistance
end

function RacketingRopeConstraint:_isValid()
	return self._obj.Attachment0 and self._obj.Attachment1 and self._obj.Enabled
end

function RacketingRopeConstraint:_handleActiveChanged()
	if self:_isValid() then
		if self._maid._updateHeartbeat and self._maid._updateHeartbeat.Connected then
			return
		end

		-- Heartbeast is after simulation, but before render, and if we want our stuff
		-- to render proper, this is when to do it!
		self._maid._updateHeartbeat = RunService.Heartbeat:Connect(function()
			self:_update()
		end)

		self:_update()
	else
		self._isConstrained.Value = false
		self._maid._updateHeartbeat = nil
		self._maid._pendingConstrainedPromise = nil
		self._smallestDistance = START_DISTANCE
		self:_setLength(self._smallestDistance)
	end
end

function RacketingRopeConstraint:_update()
	assert(self:_isValid(), "Not valid state")

	local currentDistance = (self._obj.Attachment0.WorldPosition - self._obj.Attachment1.WorldPosition).magnitude
	self._smallestDistance = math.clamp(currentDistance, self._targetDistance, self._smallestDistance)

	self:_setLength(self._smallestDistance)

	if self:_queryIsConstrained() then
		self._maid._updateHeartbeat = nil
		self._isConstrained.Value = true

		if self._maid._pendingConstrainedPromise then
			if self:_isValid() and self:_queryIsConstrained() then
				self._maid._pendingConstrainedPromise:Resolve()
			end

			self._maid._pendingConstrainedPromise = nil
		end
	else
		self._isConstrained.Value = false
	end
end

function RacketingRopeConstraint:_setLength(length)
	if self._overriddenLength then
		self._overriddenLength:Set(length)
	else
		self._obj.Length = length
	end
end

return Binder.new("RacketingRopeConstraint", RacketingRopeConstraint)