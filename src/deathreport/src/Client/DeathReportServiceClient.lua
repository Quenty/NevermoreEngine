--!strict
--[=[
	Centralized death reporting service which can be used to track
	deaths.

	@client
	@class DeathReportServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeathReportProcessor = require("DeathReportProcessor")
local DeathReportServiceConstants = require("DeathReportServiceConstants")
local DeathReportUtils = require("DeathReportUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerDeathTrackerClient = require("PlayerDeathTrackerClient")
local PlayerKillTrackerClient = require("PlayerKillTrackerClient")
local PlayerMock = require("PlayerMock")
local Remoting = require("Remoting")
local ServiceBag = require("ServiceBag")
local Signal = require("Signal")
local TeamKillTrackerClient = require("TeamKillTrackerClient")

-- Note: don't make this too big without upgrading the way we handle the queue
local MAX_DEATH_REPORTS = 5

local DeathReportServiceClient = {}
DeathReportServiceClient.ServiceName = "DeathReportServiceClient"

export type DeathReportServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		NewDeathReport: Signal.Signal<DeathReportUtils.DeathReport>,
		_remoting: Remoting.Remoting,
		_reportProcessor: DeathReportProcessor.DeathReportProcessor,
		_lastDeathReports: { DeathReportUtils.DeathReport },
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

	-- Binders
	self._serviceBag:GetService(TeamKillTrackerClient)
	self._serviceBag:GetService(PlayerKillTrackerClient)
	self._serviceBag:GetService(PlayerDeathTrackerClient)

	--[=[
	Fires with every [DeathReport] the server replicates
	@prop NewDeathReport Signal<DeathReport>
	@within DeathReportServiceClient
]=]
	self.NewDeathReport = self._maid:Add(Signal.new()) :: any

	self._reportProcessor = self._maid:Add(DeathReportProcessor.new())
	self._lastDeathReports = {}

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
	assert(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")

	return self._reportProcessor:ObservePlayerKillerReports(player)
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
	assert(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")

	return self._reportProcessor:ObservePlayerDeathReports(player)
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
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	return self._reportProcessor:ObserveHumanoidKillerReports(humanoid)
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
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	return self._reportProcessor:ObserveHumanoidDeathReports(humanoid)
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
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")

	return self._reportProcessor:ObserveCharacterKillerReports(character)
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
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")

	return self._reportProcessor:ObserveCharacterDeathReports(character)
end

--[=[
	Gets the last recorded death reports, oldest first
	@return { DeathReport }
]=]
function DeathReportServiceClient.GetLastDeathReports(self: DeathReportServiceClient): { DeathReportUtils.DeathReport }
	return self._lastDeathReports
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

	-- Hack O(2*n) operation for death reports, but since n is really low, it's all good.
	table.insert(self._lastDeathReports, deathReport)
	while #self._lastDeathReports > MAX_DEATH_REPORTS do
		table.remove(self._lastDeathReports, 1)
	end

	-- Fire off events
	self.NewDeathReport:Fire(deathReport)
	self._reportProcessor:HandleDeathReport(deathReport)
end

function DeathReportServiceClient.Destroy(self: DeathReportServiceClient)
	self._maid:DoCleaning()
end

return DeathReportServiceClient
