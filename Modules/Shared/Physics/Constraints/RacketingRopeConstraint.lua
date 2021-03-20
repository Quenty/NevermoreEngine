--- Tries to racket back down to a reasonable length
-- @classmod RacketingRopeConstraint
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local OverriddenProperty = require("OverriddenProperty")
local Promise = require("Promise")

local START_DISTANCE = 1000

local RacketingRopeConstraint = setmetatable({}, BaseObject)
RacketingRopeConstraint.ClassName = "RacketingRopeConstraint"
RacketingRopeConstraint.__index = RacketingRopeConstraint

function RacketingRopeConstraint.new(ropeConstraint)
	local self = setmetatable(BaseObject.new(ropeConstraint), RacketingRopeConstraint)

	self._smallestDistance = START_DISTANCE
	self._targetDistance = 0.5

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
		self._overriddenLength = OverriddenProperty.new(self._obj, "Length")
		self._maid:GiveTask(self._overriddenLength)
	end

	return self
end

function RacketingRopeConstraint:PromiseConstrained()
	if self:_isValid() and self:_isConstrained() then
		return Promise.resolved()
	end

	if self._maid._pendingConstrainedPromise then
		return self._maid._pendingConstrainedPromise
	end

	local promise = Promise.new()
	self._maid._pendingConstrainedPromise = promise
	return promise
end

function RacketingRopeConstraint:_isConstrained()
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
		self._maid._updateHeartbeat = nil
		self._maid._pendingConstrainedPromise = nil
		self._smallestDistance = START_DISTANCE
		self:_setLength(self._smallestDistance)
	end
end

function RacketingRopeConstraint:_update()
	assert(self:_isValid())

	local currentDistance = (self._obj.Attachment0.WorldPosition - self._obj.Attachment1.WorldPosition).magnitude
	self._smallestDistance = math.clamp(currentDistance, self._targetDistance, self._smallestDistance)

	self:_setLength(self._smallestDistance)

	if self:_isConstrained() then
		self._maid._updateHeartbeat = nil

		if self._maid._pendingConstrainedPromise then
			if self:_isValid() and self:_isConstrained() then
				self._maid._pendingConstrainedPromise:Resolve()
			end

			self._maid._pendingConstrainedPromise = nil
		end
	end
end

function RacketingRopeConstraint:_setLength(length)
	if self._overriddenLength then
		self._overriddenLength:Set(length)
	else
		self._obj.Length = length
	end
end

return RacketingRopeConstraint