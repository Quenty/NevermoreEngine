--[=[
	@class DeathTrackedHumanoid
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local DeathReportService = require("DeathReportService")

local DeathTrackedHumanoid = setmetatable({}, BaseObject)
DeathTrackedHumanoid.ClassName = "DeathTrackedHumanoid"
DeathTrackedHumanoid.__index = DeathTrackedHumanoid

function DeathTrackedHumanoid.new(humanoid: Humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), DeathTrackedHumanoid)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._deathReportService = self._serviceBag:GetService(DeathReportService)

	self._maid._diedEvent = self._obj:GetPropertyChangedSignal("Health"):Connect(function()
		self:_handleDeath()
	end)

	return self
end

function DeathTrackedHumanoid:_handleDeath()
	-- make sure we haven't already reported and this is a deferred event.
	if not self._maid._diedEvent then
		return
	end

	if self._obj.Health <= 0 then
		self._maid._diedEvent = nil -- prevent double tracking of death
		self._deathReportService:ReportHumanoidDeath(self._obj)
	end
end

return DeathTrackedHumanoid