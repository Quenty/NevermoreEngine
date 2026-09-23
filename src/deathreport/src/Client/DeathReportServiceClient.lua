--!strict
--[=[
	Centralized death reporting service which can be used to track
	deaths. Receives the reports [DeathReportService] replicates and feeds them to
	[DeathReportDataService], which this service aliases.

	@client
	@class DeathReportServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeathReportDataService = require("DeathReportDataService")
local DeathReportServiceConstants = require("DeathReportServiceConstants")
local DeathReportUtils = require("DeathReportUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerDeathTrackerClient = require("PlayerDeathTrackerClient")
local PlayerKillTrackerClient = require("PlayerKillTrackerClient")
local Remoting = require("Remoting")
local ServiceBag = require("ServiceBag")
local Signal = require("Signal")
local TeamKillTrackerClient = require("TeamKillTrackerClient")

local DeathReportServiceClient = {}
DeathReportServiceClient.ServiceName = "DeathReportServiceClient"

export type DeathReportServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_dataService: DeathReportDataService.DeathReportDataService,
		NewDeathReport: Signal.Signal<DeathReportUtils.DeathReport>,
		_remoting: Remoting.Remoting,
	},
	{} :: typeof({ __index = DeathReportServiceClient })
))

--[=[
	Initializes the death report service for the given service bag. Should be done
	via [ServiceBag].

	@param serviceBag ServiceBag
]=]
function DeathReportServiceClient.Init(self: DeathReportServiceClient, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- Internal
	self._dataService = self._serviceBag:GetService(DeathReportDataService) :: any

	-- Binders
	self._serviceBag:GetService(TeamKillTrackerClient)
	self._serviceBag:GetService(PlayerKillTrackerClient)
	self._serviceBag:GetService(PlayerDeathTrackerClient)

	--[=[
	Fires with every [DeathReport] the server replicates. Same signal as
	[DeathReportDataService.NewDeathReport].
	@prop NewDeathReport Signal<DeathReport>
	@within DeathReportServiceClient
]=]
	self.NewDeathReport = self._dataService.NewDeathReport

	self._remoting = self._maid:Add(Remoting.Client.new(ReplicatedStorage, DeathReportServiceConstants.REMOTING_NAME))
	self._maid:GiveTask(
		self._remoting:Connect(DeathReportServiceConstants.DEATH_REPORTED_EVENT_NAME, function(deathReport)
			self:_handleClientEvent(deathReport)
		end)
	)
end

--[=[
	Observes killer reports for the given player

	@param player Player
	@return Observable<DeathReport>
]=]
function DeathReportServiceClient.ObservePlayerKillerReports(
	self: DeathReportServiceClient,
	player: Player
): Observable.Observable<DeathReportUtils.DeathReport>
	return self._dataService:ObservePlayerKillerReports(player)
end

--[=[
	Observes death reports for the given player

	@param player Player
	@return Observable<DeathReport>
]=]
function DeathReportServiceClient.ObservePlayerDeathReports(
	self: DeathReportServiceClient,
	player: Player
): Observable.Observable<DeathReportUtils.DeathReport>
	return self._dataService:ObservePlayerDeathReports(player)
end

--[=[
	Observes killer reports for the given humanoid

	@param humanoid Humanoid
	@return Observable<DeathReport>
]=]
function DeathReportServiceClient.ObserveHumanoidKillerReports(
	self: DeathReportServiceClient,
	humanoid: Humanoid
): Observable.Observable<DeathReportUtils.DeathReport>
	return self._dataService:ObserveHumanoidKillerReports(humanoid)
end

--[=[
	Observes death reports for the given humanoid

	@param humanoid Humanoid
	@return Observable<DeathReport>
]=]
function DeathReportServiceClient.ObserveHumanoidDeathReports(
	self: DeathReportServiceClient,
	humanoid: Humanoid
): Observable.Observable<DeathReportUtils.DeathReport>
	return self._dataService:ObserveHumanoidDeathReports(humanoid)
end

--[=[
	Observes killer reports for the given character

	@param character Model
	@return Observable<DeathReport>
]=]
function DeathReportServiceClient.ObserveCharacterKillerReports(
	self: DeathReportServiceClient,
	character: Model
): Observable.Observable<DeathReportUtils.DeathReport>
	return self._dataService:ObserveCharacterKillerReports(character)
end

--[=[
	Observes death reports for the given character

	@param character Model
	@return Observable<DeathReport>
]=]
function DeathReportServiceClient.ObserveCharacterDeathReports(
	self: DeathReportServiceClient,
	character: Model
): Observable.Observable<DeathReportUtils.DeathReport>
	return self._dataService:ObserveCharacterDeathReports(character)
end

--[=[
	Gets the last recorded death reports, oldest first
	@return { DeathReport }
]=]
function DeathReportServiceClient.GetLastDeathReports(self: DeathReportServiceClient): { DeathReportUtils.DeathReport }
	return self._dataService:GetLastDeathReports()
end

function DeathReportServiceClient._handleClientEvent(
	self: DeathReportServiceClient,
	deathReport: DeathReportUtils.DeathReport
)
	assert(DeathReportUtils.isDeathReport(deathReport), "Bad deathreport")

	if typeof(deathReport.adornee) ~= "Instance" then
		warn("[DeathReportServiceClient] - Failed to get adornee of deathReport. Probably not streamed in.")
		return
	end

	self._dataService:HandleDeathReport(deathReport)
end

function DeathReportServiceClient.Destroy(self: DeathReportServiceClient)
	self._maid:DoCleaning()
end

return DeathReportServiceClient
