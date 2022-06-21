--[=[
	Centralized death reporting service which can be used to track
	deaths.

	@server
	@class DeathReportService
]=]

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local GetRemoteEvent = require("GetRemoteEvent")
local DeathReportServiceConstants = require("DeathReportServiceConstants")
local DeathReportUtils = require("DeathReportUtils")
local Maid = require("Maid")
local DeathReportProcessor = require("DeathReportProcessor")

local DeathReportService = {}

--[=[
	Initializes the DeathReportService. Should be done via [ServiceBag].

	@param serviceBag ServiceBag
]=]
function DeathReportService:Init(serviceBag)
	assert(not self.NewDeathReport, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- Internal
	self._serviceBag:GetService(require("DeathReportBindersServer"))

	-- Configure
	self.NewDeathReport = Signal.new()
	self._maid:GiveTask(self.NewDeathReport)

	self._remoteEvent = GetRemoteEvent(DeathReportServiceConstants.REMOTE_EVENT_NAME)

	self._reportProcessor = DeathReportProcessor.new()
	self._maid:GiveTask(self._reportProcessor)
end

--[=[
	Observes killer reports for the given player

	@param player Player
	@return Observable<DeathReport>
]=]
function DeathReportService:ObservePlayerKillerReports(player)
	return self._reportProcessor:ObservePlayerKillerReports(player)
end

--[=[
	Observes death reports for the given player

	@param player Player
	@return Observable<DeathReport>
]=]
function DeathReportService:ObservePlayerDeathReports(player)
	return self._reportProcessor:ObservePlayerDeathReports(player)
end

--[=[
	Reports the death of a humanoid. This is called automatically
	by [DeathTrackedHumanoid].

	@param humanoid Humanoid -- Humanoid that died
]=]
function DeathReportService:ReportDeath(humanoid)
	local report = DeathReportUtils.fromDeceasedHumanoid(humanoid)

	-- Notify services
	self.NewDeathReport:Fire(report)

	self._reportProcessor:HandleDeathReport(report)

	-- Send to all clients
	self._remoteEvent:FireAllClients(report)
end

function DeathReportService:Destroy()
	self._maid:DoCleaning()
end

return DeathReportService