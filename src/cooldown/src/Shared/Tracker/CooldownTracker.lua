--[=[
	Tracks current cooldown on an object
	@class CooldownTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local CooldownShared = require("CooldownShared")
local CooldownTrackerModel = require("CooldownTrackerModel")
local Maid = require("Maid")
local RxBinderUtils = require("RxBinderUtils")
local ValueObject = require("ValueObject")

local CooldownTracker = setmetatable({}, BaseObject)
CooldownTracker.ClassName = "CooldownTracker"
CooldownTracker.__index = CooldownTracker

function CooldownTracker.new(serviceBag, parent)
	assert(typeof(parent) == "Instance", "Bad parent")

	local self = setmetatable(BaseObject.new(parent), CooldownTracker)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._cooldownBinder = self._serviceBag:GetService(CooldownShared)

	self.CurrentCooldown = self._maid:Add(ValueObject.new(nil))
	self._cooldownTrackModel = self._maid:Add(CooldownTrackerModel.new())

	self._maid:GiveTask(self.CurrentCooldown.Changed:Connect(function(...)
		self:_handleNewCooldown(...)
	end))

	-- Handle not running
	self._maid:GiveTask(
		RxBinderUtils.observeBoundChildClassBrio(self._cooldownBinder, self._obj):Subscribe(function(brio)
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

function CooldownTracker:GetCooldownTrackerModel()
	return self._cooldownTrackModel
end

function CooldownTracker:IsCoolingDown(): boolean
	return self._cooldownTrackModel:IsCoolingDown()
end

function CooldownTracker:_handleNewCooldown(new, _old)
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
