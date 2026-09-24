--!strict
--[=[
	Realm-agnostic core of death reporting. Owns the per-subject report observers, the
	[DeathReportDataService.NewDeathReport] signal and the recent-report queue that
	[DeathReportService] and [DeathReportServiceClient] both expose. Each realm's service
	feeds it reports -- the server from [DeathTrackedHumanoid], the client from remoting --
	and aliases its observers.

	@class DeathReportDataService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Brio = require("Brio")
local DeathReportUtils = require("DeathReportUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")
local PlayerDeathTrackerInterface = require("PlayerDeathTrackerInterface")
local PlayerKillTrackerInterface = require("PlayerKillTrackerInterface")
local PlayerMock = require("PlayerMock")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local ServiceBag = require("ServiceBag")
local Signal = require("Signal")
local TeamKillTrackerInterface = require("TeamKillTrackerInterface")
local TieInterface = require("TieInterface")
local TieRealmService = require("TieRealmService")

-- Note: don't make this too big without upgrading the way we handle the queue
local MAX_DEATH_REPORTS = 5

local DeathReportDataService = {}
DeathReportDataService.ServiceName = "DeathReportDataService"

export type DeathReportDataService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_tieRealmService: TieRealmService.TieRealmService,
		_maid: Maid.Maid,
		NewDeathReport: Signal.Signal<DeathReportUtils.DeathReport>,
		_lastDeathReports: { DeathReportUtils.DeathReport },
		_playerKillerSubTable: ObservableSubscriptionTable.ObservableSubscriptionTable<DeathReportUtils.DeathReport>,
		_playerDeathSubTable: ObservableSubscriptionTable.ObservableSubscriptionTable<DeathReportUtils.DeathReport>,
		_humanoidKillerSubTable: ObservableSubscriptionTable.ObservableSubscriptionTable<DeathReportUtils.DeathReport>,
		_humanoidDeathSubTable: ObservableSubscriptionTable.ObservableSubscriptionTable<DeathReportUtils.DeathReport>,
		_characterKillerSubTable: ObservableSubscriptionTable.ObservableSubscriptionTable<DeathReportUtils.DeathReport>,
		_characterDeathSubTable: ObservableSubscriptionTable.ObservableSubscriptionTable<DeathReportUtils.DeathReport>,
	},
	{} :: typeof({ __index = DeathReportDataService })
))

--[=[
	Initializes the service. Should be done via [ServiceBag].
]=]
function DeathReportDataService.Init(self: DeathReportDataService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._tieRealmService = self._serviceBag:GetService(TieRealmService) :: any

	--[=[
	Fires with every [DeathReport] handled in this realm
	@prop NewDeathReport Signal<DeathReport>
	@within DeathReportDataService
]=]
	self.NewDeathReport = self._maid:Add(Signal.new()) :: any

	self._lastDeathReports = {}

	self._playerKillerSubTable = self._maid:Add(ObservableSubscriptionTable.new() :: any)
	self._playerDeathSubTable = self._maid:Add(ObservableSubscriptionTable.new() :: any)
	self._humanoidKillerSubTable = self._maid:Add(ObservableSubscriptionTable.new() :: any)
	self._humanoidDeathSubTable = self._maid:Add(ObservableSubscriptionTable.new() :: any)
	self._characterKillerSubTable = self._maid:Add(ObservableSubscriptionTable.new() :: any)
	self._characterDeathSubTable = self._maid:Add(ObservableSubscriptionTable.new() :: any)

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		self:_handlePlayerRemoving(player)
	end))

	-- Mocks are invisible to the Players service, so their removal is the counterpart of
	-- PlayerRemoving.
	self._maid:GiveTask(PlayerMock.getMockRemovingSignal():Connect(function(player)
		self:_handlePlayerRemoving(player)
	end))
end

function DeathReportDataService._handlePlayerRemoving(self: DeathReportDataService, player: Player)
	self._playerKillerSubTable:Complete(player)
	self._playerDeathSubTable:Complete(player)
end

--[=[
	Observes killer reports for the given player
]=]
function DeathReportDataService.ObservePlayerKillerReports(
	self: DeathReportDataService,
	player: Player
): Observable.Observable<DeathReportUtils.DeathReport>
	assert(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")

	return self._playerKillerSubTable:Observe(player)
end

--[=[
	Observes death reports for the given player
]=]
function DeathReportDataService.ObservePlayerDeathReports(
	self: DeathReportDataService,
	player: Player
): Observable.Observable<DeathReportUtils.DeathReport>
	assert(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")

	return self._playerDeathSubTable:Observe(player)
end

--[=[
	Observes killer reports for the given humanoid
]=]
function DeathReportDataService.ObserveHumanoidKillerReports(
	self: DeathReportDataService,
	humanoid: Humanoid
): Observable.Observable<DeathReportUtils.DeathReport>
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	return self._humanoidKillerSubTable:Observe(humanoid)
end

--[=[
	Observes death reports for the given humanoid
]=]
function DeathReportDataService.ObserveHumanoidDeathReports(
	self: DeathReportDataService,
	humanoid: Humanoid
): Observable.Observable<DeathReportUtils.DeathReport>
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	return self._humanoidDeathSubTable:Observe(humanoid)
end

--[=[
	Observes killer reports for the given character
]=]
function DeathReportDataService.ObserveCharacterKillerReports(
	self: DeathReportDataService,
	character: Model
): Observable.Observable<DeathReportUtils.DeathReport>
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")

	return self._characterKillerSubTable:Observe(character)
end

--[=[
	Observes death reports for the given character
]=]
function DeathReportDataService.ObserveCharacterDeathReports(
	self: DeathReportDataService,
	character: Model
): Observable.Observable<DeathReportUtils.DeathReport>
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")

	return self._characterDeathSubTable:Observe(character)
end

--[=[
	Observes the [PlayerKillTracker] bound to the player, through [PlayerKillTrackerInterface] in
	this realm.
]=]
function DeathReportDataService.ObservePlayerKillTrackerBrio(
	self: DeathReportDataService,
	player: Player
): Observable.Observable<
	Brio.Brio<TieInterface.TieInterface<any>>
>
	assert(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")

	return PlayerKillTrackerInterface:ObserveBrio(player, self._tieRealmService:GetTieRealm()) :: any
end

--[=[
	Observes the [PlayerDeathTracker] bound to the player, through [PlayerDeathTrackerInterface] in
	this realm.
]=]
function DeathReportDataService.ObservePlayerDeathTrackerBrio(
	self: DeathReportDataService,
	player: Player
): Observable.Observable<
	Brio.Brio<TieInterface.TieInterface<any>>
>
	assert(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")

	return PlayerDeathTrackerInterface:ObserveBrio(player, self._tieRealmService:GetTieRealm()) :: any
end

--[=[
	Observes the [TeamKillTracker] bound under the team, through [TeamKillTrackerInterface] in this
	realm.
]=]
function DeathReportDataService.ObserveTeamKillTrackerBrio(
	self: DeathReportDataService,
	team: Team
): Observable.Observable<
	Brio.Brio<TieInterface.TieInterface<any>>
>
	assert(typeof(team) == "Instance" and team:IsA("Team"), "Bad team")

	return TeamKillTrackerInterface:ObserveChildrenBrio(team, self._tieRealmService:GetTieRealm()) :: any
end

--[=[
	Observes the number of kills scored by the player. Emits nil -- rather than staying silent --
	while no [PlayerKillTracker] is bound to the player, so a subscriber always has a current answer.
]=]
function DeathReportDataService.ObservePlayerKillCount(
	self: DeathReportDataService,
	player: Player
): Observable.Observable<number?>
	return self:ObservePlayerKillTrackerBrio(player):Pipe({
		RxBrioUtils.switchMapBrio(function(tracker)
			return tracker:ObserveKills()
		end) :: any,
		RxBrioUtils.emitOnDeath(nil) :: any,
		Rx.defaultsToNil :: any,
	}) :: any
end

--[=[
	Observes the number of deaths of the player. Emits nil -- rather than staying silent -- while no
	[PlayerDeathTracker] is bound to the player.
]=]
function DeathReportDataService.ObservePlayerDeathCount(
	self: DeathReportDataService,
	player: Player
): Observable.Observable<number?>
	return self:ObservePlayerDeathTrackerBrio(player):Pipe({
		RxBrioUtils.switchMapBrio(function(tracker)
			return tracker:ObserveDeaths()
		end) :: any,
		RxBrioUtils.emitOnDeath(nil) :: any,
		Rx.defaultsToNil :: any,
	}) :: any
end

--[=[
	Observes the number of kills scored by the team. Emits nil -- rather than staying silent -- while
	no [TeamKillTracker] is bound under the team.
]=]
function DeathReportDataService.ObserveTeamKillCount(
	self: DeathReportDataService,
	team: Team
): Observable.Observable<number?>
	return self:ObserveTeamKillTrackerBrio(team):Pipe({
		RxBrioUtils.switchMapBrio(function(tracker)
			return tracker:ObserveKills()
		end) :: any,
		RxBrioUtils.emitOnDeath(nil) :: any,
		Rx.defaultsToNil :: any,
	}) :: any
end

--[=[
	Gets the last recorded death reports, oldest first
]=]
function DeathReportDataService.GetLastDeathReports(self: DeathReportDataService): { DeathReportUtils.DeathReport }
	return self._lastDeathReports
end

--[=[
	Records a death report: remembers it, fires [DeathReportDataService.NewDeathReport] and routes
	it to the observers. Replication is the realm service's job.
]=]
function DeathReportDataService.HandleDeathReport(
	self: DeathReportDataService,
	deathReport: DeathReportUtils.DeathReport
)
	assert(DeathReportUtils.isDeathReport(deathReport), "Bad deathReport")

	-- Hack O(2*n) operation for death reports, but since n is really low, it's all good.
	table.insert(self._lastDeathReports, deathReport)
	while #self._lastDeathReports > MAX_DEATH_REPORTS do
		table.remove(self._lastDeathReports, 1)
	end

	self.NewDeathReport:Fire(deathReport)

	if deathReport.killerPlayer then
		self._playerKillerSubTable:Fire(deathReport.killerPlayer, deathReport)
	end

	if deathReport.killerHumanoid then
		self._humanoidKillerSubTable:Fire(deathReport.killerHumanoid, deathReport)

		local character = deathReport.killerHumanoid.Parent
		if character then
			self._characterKillerSubTable:Fire(character, deathReport)
		end
	end

	if deathReport.player then
		self._playerDeathSubTable:Fire(deathReport.player, deathReport)
	end

	if deathReport.humanoid then
		self._humanoidDeathSubTable:Fire(deathReport.humanoid, deathReport)

		local character = deathReport.humanoid.Parent
		if character then
			self._characterDeathSubTable:Fire(character, deathReport)
		end
	end
end

function DeathReportDataService.Destroy(self: DeathReportDataService)
	self._maid:DoCleaning()
end

return DeathReportDataService
