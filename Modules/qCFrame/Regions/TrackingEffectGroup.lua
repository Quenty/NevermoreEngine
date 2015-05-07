local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local Signal = LoadCustomLibrary("Signal")
local EffectGroup = LoadCustomLibrary("EffectGroup")

-- Like an effect group, except it tracks the active one and has an event for that.
-- @author Quenty

local TrackingEffectGroup = {}
TrackingEffectGroup.__index = TrackingEffectGroup
TrackingEffectGroup.ClassName = "TrackingEffectGroup"
setmetatable(TrackingEffectGroup, EffectGroup)

function TrackingEffectGroup.new()
	local self = EffectGroup.new()
	setmetatable(self, TrackingEffectGroup)

	self.ActiveChanged = Signal.new() -- :fire(NewActive, OldActive) Where NewActive is the Effect

	return self
end

function TrackingEffectGroup:SetActive(NewActive)
	--- Fires the event too!
	-- @param NewActive May be nil. If so, clears the active tracker.

	if self.Active ~= NewActive then
		local OldActive = self.Active

		self.Active = NewActive
		self.ActiveChanged:fire(NewActive, OldActive)
	end
end

function TrackingEffectGroup:Update(Point)
	-- @param Point A Vector3 point to check as the active location.

	local Active = self:FindFirstActive(Point)
	self:SetActive(Active)
end

return TrackingEffectGroup