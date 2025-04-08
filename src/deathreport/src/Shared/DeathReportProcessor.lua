--!strict
--[=[
	Handles shared observable subscription tables for the client and server

	@class DeathReportProcessor
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local BaseObject = require("BaseObject")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")
local DeathReportUtils = require("DeathReportUtils")
local _Observable = require("Observable")

local DeathReportProcessor = setmetatable({}, BaseObject)
DeathReportProcessor.ClassName = "DeathReportProcessor"
DeathReportProcessor.__index = DeathReportProcessor

export type DeathReportProcessor = typeof(setmetatable(
	{} :: {
		_playerKillerSubTable: ObservableSubscriptionTable.ObservableSubscriptionTable<DeathReportUtils.DeathReport>,
		_playerDeathSubTable: ObservableSubscriptionTable.ObservableSubscriptionTable<DeathReportUtils.DeathReport>,
		_humanoidKillerSubTable: ObservableSubscriptionTable.ObservableSubscriptionTable<DeathReportUtils.DeathReport>,
		_humanoidDeathSubTable: ObservableSubscriptionTable.ObservableSubscriptionTable<DeathReportUtils.DeathReport>,
		_characterKillerSubTable: ObservableSubscriptionTable.ObservableSubscriptionTable<DeathReportUtils.DeathReport>,
		_characterDeathSubTable: ObservableSubscriptionTable.ObservableSubscriptionTable<DeathReportUtils.DeathReport>,
	},
	{} :: typeof({ __index = DeathReportProcessor })
)) & BaseObject.BaseObject

function DeathReportProcessor.new(): DeathReportProcessor
	local self = setmetatable(BaseObject.new() :: any, DeathReportProcessor)

	self._playerKillerSubTable = self._maid:Add(ObservableSubscriptionTable.new())
	self._playerDeathSubTable = self._maid:Add(ObservableSubscriptionTable.new())
	self._humanoidKillerSubTable = self._maid:Add(ObservableSubscriptionTable.new())
	self._humanoidDeathSubTable = self._maid:Add(ObservableSubscriptionTable.new())
	self._characterKillerSubTable = self._maid:Add(ObservableSubscriptionTable.new())
	self._characterDeathSubTable = self._maid:Add(ObservableSubscriptionTable.new())

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		self._playerKillerSubTable:Complete(player)
		self._playerDeathSubTable:Complete(player)
	end))

	return self
end

--[=[
	Observes killer reports for the given player

	@param player Player
	@return Observable<DeathReport>
]=]
function DeathReportProcessor.ObservePlayerKillerReports(
	self: DeathReportProcessor,
	player: Player
): _Observable.Observable<DeathReportUtils.DeathReport>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._playerKillerSubTable:Observe(player)
end

--[=[
	Observes death reports for the given player

	@param player Player
	@return Observable<DeathReport>
]=]
function DeathReportProcessor.ObservePlayerDeathReports(
	self: DeathReportProcessor,
	player: Player
): _Observable.Observable<DeathReportUtils.DeathReport>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._playerDeathSubTable:Observe(player)
end

--[=[
	Observes death reports for the given humanoid

	@param humanoid Humanoid
	@return Observable<DeathReport>
]=]
function DeathReportProcessor.ObserveHumanoidDeathReports(
	self: DeathReportProcessor,
	humanoid: Humanoid
): _Observable.Observable<DeathReportUtils.DeathReport>
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	return self._humanoidDeathSubTable:Observe(humanoid)
end

--[=[
	Observes killer reports for the given humanoid

	@param humanoid Humanoid
	@return Observable<DeathReport>
]=]
function DeathReportProcessor.ObserveHumanoidKillerReports(
	self: DeathReportProcessor,
	humanoid: Humanoid
): _Observable.Observable<DeathReportUtils.DeathReport>
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	return self._humanoidKillerSubTable:Observe(humanoid)
end

--[=[
	Observes killer reports for the given character

	@param character Model
	@return Observable<DeathReport>
]=]
function DeathReportProcessor.ObserveCharacterKillerReports(
	self: DeathReportProcessor,
	character: Model
): _Observable.Observable<DeathReportUtils.DeathReport>
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")

	return self._characterKillerSubTable:Observe(character)
end

--[=[
	Observes killer reports for the given character

	@param character Model
	@return Observable<DeathReport>
]=]
function DeathReportProcessor.ObserveCharacterDeathReports(
	self: DeathReportProcessor,
	character: Model
): _Observable.Observable<DeathReportUtils.DeathReport>
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")

	return self._characterDeathSubTable:Observe(character)
end


--[=[
	Handles the death report

	@param deathReport DeathReport
]=]
function DeathReportProcessor.HandleDeathReport(self: DeathReportProcessor,deathReport: DeathReportUtils.DeathReport)
	assert(DeathReportUtils.isDeathReport(deathReport), "Bad deathreport")

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

return DeathReportProcessor