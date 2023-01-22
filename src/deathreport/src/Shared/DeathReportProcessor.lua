--[=[
	@class DeathReportProcessor
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local BaseObject = require("BaseObject")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")
local DeathReportUtils = require("DeathReportUtils")

local DeathReportProcessor = setmetatable({}, BaseObject)
DeathReportProcessor.ClassName = "DeathReportProcessor"
DeathReportProcessor.__index = DeathReportProcessor

function DeathReportProcessor.new()
	local self = setmetatable(BaseObject.new(), DeathReportProcessor)

	self._playerKillerSubTable = ObservableSubscriptionTable.new()
	self._maid:GiveTask(self._playerKillerSubTable)

	self._playerDeathSubTable = ObservableSubscriptionTable.new()
	self._maid:GiveTask(self._playerDeathSubTable)

	self._humanoidKillerSubTable = ObservableSubscriptionTable.new()
	self._maid:GiveTask(self._humanoidKillerSubTable)

	self._humanoidDeathSubTable = ObservableSubscriptionTable.new()
	self._maid:GiveTask(self._humanoidDeathSubTable)

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
function DeathReportProcessor:ObservePlayerKillerReports(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._playerKillerSubTable:Observe(player)
end

--[=[
	Observes death reports for the given player

	@param player Player
	@return Observable<DeathReport>
]=]
function DeathReportProcessor:ObservePlayerDeathReports(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._playerDeathSubTable:Observe(player)
end

--[=[
	Observes death reports for the given humanoid

	@param humanoid Humanoid
	@return Observable<DeathReport>
]=]
function DeathReportProcessor:ObserveHumanoidDeathReports(humanoid)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	return self._humanoidDeathSubTable:Observe(humanoid)
end

--[=[
	Observes killer reports for the given humanoid

	@param humanoid Humanoid
	@return Observable<DeathReport>
]=]
function DeathReportProcessor:ObserveHumanoidKillerReports(humanoid)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	return self._humanoidKillerSubTable:Observe(humanoid)
end

--[=[
	Handles the death report

	@param deathReport DeathReport
]=]
function DeathReportProcessor:HandleDeathReport(deathReport)
	assert(DeathReportUtils.isDeathReport(deathReport), "Bad deathreport")

	if deathReport.killerPlayer then
		self._playerKillerSubTable:Fire(deathReport.killerPlayer, deathReport)
	end

	if deathReport.killerHumanoid then
		self._humanoidKillerSubTable:Fire(deathReport.killerHumanoid, deathReport)
	end

	if deathReport.player then
		self._playerDeathSubTable:Fire(deathReport.player, deathReport)
	end

	if deathReport.humanoid then
		self._humanoidDeathSubTable:Fire(deathReport.humanoid, deathReport)
	end
end

return DeathReportProcessor