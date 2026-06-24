--!strict
--[=[
	@class DeathTrackedHumanoid
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local DeathReportService = require("DeathReportService")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")
local ServiceBag = require("ServiceBag")

local DeathTrackedHumanoid = setmetatable({}, BaseObject)
DeathTrackedHumanoid.ClassName = "DeathTrackedHumanoid"
DeathTrackedHumanoid.__index = DeathTrackedHumanoid

export type DeathTrackedHumanoid =
	typeof(setmetatable(
		{} :: {
			_obj: Humanoid,
			_serviceBag: ServiceBag.ServiceBag,
			_deathReportService: DeathReportService.DeathReportService,
		},
		{} :: typeof({ __index = DeathTrackedHumanoid })
	))
	& BaseObject.BaseObject

function DeathTrackedHumanoid.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag): DeathTrackedHumanoid
	local self: DeathTrackedHumanoid = setmetatable(BaseObject.new(humanoid) :: any, DeathTrackedHumanoid)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._deathReportService = self._serviceBag:GetService(DeathReportService) :: any

	self._maid._diedEvent = self._obj:GetPropertyChangedSignal("Health"):Connect(function()
		self:_handleDeath()
	end)

	return self
end

function DeathTrackedHumanoid._handleDeath(self: DeathTrackedHumanoid)
	-- make sure we haven't already reported and this is a deferred event.
	if not self._maid._diedEvent then
		return
	end

	if self._obj.Health <= 0 then
		self._maid._diedEvent = nil -- prevent double tracking of death
		self._deathReportService:ReportHumanoidDeath(self._obj)
	end
end

return PlayerHumanoidBinder.new("DeathTrackedHumanoid", DeathTrackedHumanoid)
