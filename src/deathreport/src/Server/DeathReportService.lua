--!strict
--[=[
	Centralized death reporting service which can be used to track
	deaths.

	@server
	@class DeathReportService
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeathReportProcessor = require("DeathReportProcessor")
local DeathReportServiceConstants = require("DeathReportServiceConstants")
local DeathReportUtils = require("DeathReportUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerMock = require("PlayerMock")
local Remoting = require("Remoting")
local ServiceBag = require("ServiceBag")
local Signal = require("Signal")

local DeathReportService = {}
DeathReportService.ServiceName = "DeathReportService"

export type DeathReportService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		NewDeathReport: Signal.Signal<DeathReportUtils.DeathReport>,
		_remoting: Remoting.Remoting,
		_reportProcessor: DeathReportProcessor.DeathReportProcessor,
		_weaponDataRetrievers: { GetWeaponData },
	},
	{} :: typeof({ __index = DeathReportService })
))

export type GetWeaponData = (humanoid: Humanoid) -> DeathReportUtils.WeaponData?

--[=[
	Initializes the DeathReportService. Should be done via [ServiceBag].

	@param serviceBag ServiceBag
]=]
function DeathReportService.Init(self: DeathReportService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- Binders. Required lazily: each one requires this service at load time.
	self._serviceBag:GetService((require :: any)("DeathTrackedHumanoid"))
	self._serviceBag:GetService((require :: any)("TeamKillTracker"))
	self._serviceBag:GetService((require :: any)("PlayerKillTracker"))
	self._serviceBag:GetService((require :: any)("PlayerDeathTracker"))

	--[=[
	Fires with every [DeathReport] the server records
	@prop NewDeathReport Signal<DeathReport>
	@within DeathReportService
]=]
	self.NewDeathReport = self._maid:Add(Signal.new()) :: any

	-- State
	self._remoting = self._maid:Add(Remoting.Server.new(ReplicatedStorage, DeathReportServiceConstants.REMOTING_NAME))
	self._remoting:DeclareEvent(DeathReportServiceConstants.DEATH_REPORTED_EVENT_NAME)

	self._reportProcessor = self._maid:Add(DeathReportProcessor.new())

	self._weaponDataRetrievers = {}
end

--[=[
	Registers a callback that resolves the weapon a humanoid died to. Retrievers are asked in
	registration order; the first non-nil answer wins.

	@param getWeaponData (humanoid: Humanoid) -> WeaponData?
	@return () -> () -- Removes the retriever
]=]
function DeathReportService.AddWeaponDataRetriever(self: DeathReportService, getWeaponData: GetWeaponData): () -> ()
	assert(type(getWeaponData) == "function", "Bad getWeaponData")

	table.insert(self._weaponDataRetrievers, getWeaponData)

	return function()
		local index = table.find(self._weaponDataRetrievers, getWeaponData)
		if index then
			table.remove(self._weaponDataRetrievers, index)
		end
	end
end

--[=[
	Asks the registered retrievers for the weapon the humanoid died to

	@param humanoid Humanoid
	@return WeaponData?
]=]
function DeathReportService.FindWeaponData(self: DeathReportService, humanoid: Humanoid): DeathReportUtils.WeaponData?
	assert(typeof(humanoid) == "Instance", "Bad humanoid")

	for _, item in self._weaponDataRetrievers do
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
function DeathReportService.ObservePlayerKillerReports(
	self: DeathReportService,
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
function DeathReportService.ObservePlayerDeathReports(
	self: DeathReportService,
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
function DeathReportService.ObserveHumanoidKillerReports(
	self: DeathReportService,
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
function DeathReportService.ObserveHumanoidDeathReports(
	self: DeathReportService,
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
function DeathReportService.ObserveCharacterKillerReports(
	self: DeathReportService,
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
function DeathReportService.ObserveCharacterDeathReports(
	self: DeathReportService,
	character: Model
): Observable.Observable<DeathReportUtils.DeathReport>
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")

	return self._reportProcessor:ObserveCharacterDeathReports(character)
end

--[=[
	Reports the death of a humanoid. This is called automatically
	by [DeathTrackedHumanoid].

	@param humanoid Humanoid -- Humanoid that died
	@param weaponData WeaponData? -- Weapon data to report
]=]
function DeathReportService.ReportHumanoidDeath(
	self: DeathReportService,
	humanoid: Humanoid,
	weaponData: DeathReportUtils.WeaponData?
)
	assert(typeof(humanoid) == "Instance", "Bad humanoid")

	local report = DeathReportUtils.fromDeceasedHumanoid(humanoid, weaponData or self:FindWeaponData(humanoid))

	self:ReportDeathReport(report)
end

--[=[
	Records a death report: fires [DeathReportService.NewDeathReport], routes it to the observers,
	and replicates it to every client.

	@param deathReport DeathReport
]=]
function DeathReportService.ReportDeathReport(self: DeathReportService, deathReport: DeathReportUtils.DeathReport)
	assert(DeathReportUtils.isDeathReport(deathReport), "Bad deathReport")

	-- Notify services
	self.NewDeathReport:Fire(deathReport)

	self._reportProcessor:HandleDeathReport(deathReport)

	-- Send to all clients
	self._remoting:FireAllClients(DeathReportServiceConstants.DEATH_REPORTED_EVENT_NAME, deathReport)
end

function DeathReportService.Destroy(self: DeathReportService)
	self._maid:DoCleaning()
end

return DeathReportService
