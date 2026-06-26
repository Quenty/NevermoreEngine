--!strict
--[=[
	Tracks current cooldown on an object
	@class CooldownTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local CooldownShared = require("CooldownShared")
local CooldownTrackerModel = require("CooldownTrackerModel")
local Maid = require("Maid")
local RxBinderUtils = require("RxBinderUtils")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local CooldownTracker = setmetatable({}, BaseObject)
CooldownTracker.ClassName = "CooldownTracker"
CooldownTracker.__index = CooldownTracker

export type CooldownTracker =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_cooldownBinder: Binder.Binder<CooldownShared.CooldownShared>,
			CurrentCooldown: ValueObject.ValueObject<CooldownShared.CooldownShared?>,
			_cooldownTrackModel: CooldownTrackerModel.CooldownTrackerModel,
		},
		{} :: typeof({ __index = CooldownTracker })
	))
	& BaseObject.BaseObject

function CooldownTracker.new(serviceBag: ServiceBag.ServiceBag, parent: Instance): CooldownTracker
	assert(typeof(parent) == "Instance", "Bad parent")

	local self: CooldownTracker = setmetatable(BaseObject.new(parent) :: any, CooldownTracker)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._cooldownBinder = self._serviceBag:GetService(CooldownShared)

	self.CurrentCooldown = self._maid:Add(ValueObject.new(nil))
	self._cooldownTrackModel = self._maid:Add(CooldownTrackerModel.new())

	self._maid:GiveTask(self.CurrentCooldown.Changed:Connect(function(...)
		self:_handleNewCooldown(...)
	end))

	-- Handle not running
	self._maid:GiveTask(
		RxBinderUtils.observeBoundChildClassBrio(self._cooldownBinder, self._obj :: Instance):Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			-- TODO: Use stack (with multiple cooldowns)
			local cooldown = brio:GetValue()
			local maid = brio:ToMaid()

			maid:GiveTask(self._cooldownTrackModel:SetCooldownModel(cooldown:GetCooldownModel()))

			self.CurrentCooldown.Value = cooldown

			maid:GiveTask(function()
				if not self.Destroy then
					return
				end

				if self.CurrentCooldown.Value == cooldown then
					self._cooldownTrackModel:SetCooldownModel(nil)
					self.CurrentCooldown.Value = nil
				end
			end)
		end)
	)

	return self
end

function CooldownTracker.GetCooldownTrackerModel(self: CooldownTracker): CooldownTrackerModel.CooldownTrackerModel
	return self._cooldownTrackModel
end

function CooldownTracker.IsCoolingDown(self: CooldownTracker): boolean
	return self._cooldownTrackModel:IsCoolingDown()
end

function CooldownTracker._handleNewCooldown(
	self: CooldownTracker,
	new: CooldownShared.CooldownShared?,
	_old: CooldownShared.CooldownShared?
): ()
	local maid = Maid.new()

	if new then
		maid:GiveTask(new.Done:Connect(function()
			if self.CurrentCooldown.Value == new then
				self.CurrentCooldown.Value = nil
			end
		end))
	end

	self._maid._cooldownMaid = maid
end

return CooldownTracker
