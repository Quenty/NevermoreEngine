--[=[
	Centralized death reporting service which can be used to track
	deaths.

	@client
	@class DeathReportServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local Maid = require("Maid")
local DeathReportServiceConstants = require("DeathReportServiceConstants")
local PromiseGetRemoteEvent = require("PromiseGetRemoteEvent")
local DeathReportProcessor = require("DeathReportProcessor")
local DeathReportUtils = require("DeathReportUtils")

-- Note: don't make this too big without upgrading the way we handle the queue
local MAX_DEATH_REPORTS = 5

local DeathReportServiceClient = {}

--[=[
	Initializes the death report service for the given service bag. Should be done
	via [ServiceBag].

	@param serviceBag ServiceBag
]=]
function DeathReportServiceClient:Init(serviceBag)
	assert(not self.HumanoidDied, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- Internal
	self._serviceBag:GetService(require("DeathReportBindersClient"))

	self.NewDeathReport = Signal.new()
	self._maid:GiveTask(self.NewDeathReport)

	self._reportProcessor = DeathReportProcessor.new()
	self._maid:GiveTask(self._reportProcessor)

	self._lastDeathReports = {}

	-- Setup remote Event
	self:_promiseRemoteEvent()
		:Then(function(remoteEvent)
			self._maid:GiveTask(remoteEvent.OnClientEvent:Connect(function(...)
				self:_handleClientEvent(...)
			end))
		end)
end

--[=[
	Observes killer reports for the given player

	@param player Player
	@return Observable<DeathReport>
]=]
function DeathReportServiceClient:ObservePlayerKillerReports(player)
	return self._reportProcessor:ObservePlayerKillerReports(player)
end

--[=[
	Observes death reports for the given player

	@param player Player
	@return Observable<DeathReport>
]=]
function DeathReportServiceClient:ObservePlayerDeathReports(player)
	return self._reportProcessor:ObservePlayerDeathReports(player)
end

--[=[
	Gets the last recorded death reports
	@return { DeathReport }
]=]
function DeathReportServiceClient:GetLastDeathReports()
	return self._lastDeathReports
end

function DeathReportServiceClient:_handleClientEvent(deathReport)
	assert(DeathReportUtils.isDeathReport(deathReport), "Bad deathreport")

	if typeof(deathReport.humanoid) ~= "Instance" then
		warn("[DeathReportServiceClient] - Failed to get humanoid of deathReport")
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

function DeathReportServiceClient:_promiseRemoteEvent()
	return self._maid:GivePromise(PromiseGetRemoteEvent(DeathReportServiceConstants.REMOTE_EVENT_NAME))
end

function DeathReportServiceClient:Destroy()
	self._maid:DoCleaning()
end

return DeathReportServiceClient