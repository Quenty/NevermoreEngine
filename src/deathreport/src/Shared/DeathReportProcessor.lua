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
	Handles the death report
]=]
function DeathReportProcessor:HandleDeathReport(deathReport)
	assert(DeathReportUtils.isDeathReport(deathReport), "Bad deathreport")

	if deathReport.killerPlayer then
		self._playerKillerSubTable:Fire(deathReport.killerPlayer, deathReport)
	end

	if deathReport.player then
		self._playerDeathSubTable:Fire(deathReport.player, deathReport)
	end
end

return DeathReportProcessor