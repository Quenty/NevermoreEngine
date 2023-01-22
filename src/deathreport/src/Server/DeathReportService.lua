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
DeathReportService.ServiceName = "DeathReportService"

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

	self._weaponDataRetrievers = {}
end

function DeathReportService:AddWeaponDataRetriever(getWeaponData)
	table.insert(self._weaponDataRetrievers, getWeaponData)

	return function()
		local index = table.find(self._weaponDataRetrievers, getWeaponData)
		if index then
			table.remove(self._weaponDataRetrievers, index)
		end
	end
end

function DeathReportService:FindWeaponData(humanoid)
	for _, item in pairs(self._weaponDataRetrievers) do
		local result = item(humanoid)
		if result then
			assert(DeathReportUtils.isWeaponData(result), "Failed to return valid weaponData")

			return result
		end
	end

	return nil
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
	Observes killer reports for the given humanoid

	@param humanoid Humanoid
	@return Observable<DeathReport>
]=]
function DeathReportService:ObserveHumanoidKillerReports(humanoid)
	return self._reportProcessor:ObserveHumanoidKillerReports(humanoid)
end

--[=[
	Observes death reports for the given humanoid

	@param humanoid Humanoid
	@return Observable<DeathReport>
]=]
function DeathReportService:ObserveHumanoidDeathReports(humanoid)
	return self._reportProcessor:ObserveHumanoidDeathReports(humanoid)
end

--[=[
	Reports the death of a humanoid. This is called automatically
	by [DeathTrackedHumanoid].

	@param humanoid Humanoid -- Humanoid that died
	@param weaponData WeaponData? -- Weapon data to report
]=]
function DeathReportService:ReportDeath(humanoid, weaponData)
	local report = DeathReportUtils.fromDeceasedHumanoid(humanoid, weaponData or self:FindWeaponData(humanoid))

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