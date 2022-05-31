--[=[
	Centralized death reporting service which can be used to track
	deaths.

	@server
	@class DeathReportService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Signal = require("Signal")
local GetRemoteEvent = require("GetRemoteEvent")
local DeathReportServiceConstants = require("DeathReportServiceConstants")
local DeathReportUtils = require("DeathReportUtils")
local Observable = require("Observable")
local Maid = require("Maid")
local Table = require("Table")

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

	self._killerObservations = {} -- [player] = { subscription, subscription }
	self._deathObservations = {} -- [player] = { subscription, subscription }

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		local subSet = self._deathObservations[player]
		if not subSet then
			return
		end

		-- Remove all subSet
		self._deathObservations[player] = nil

		for sub, _ in pairs(subSet) do
			sub:Complete()
		end

		-- Hope we don't recreate this!
		assert(not self._deathObservations[player], "Death observations recreated")
	end))

	-- Secondary cleanup measure!
	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		local subSet = self._killerObservations[player]
		if not subSet then
			return
		end

		-- Remove all subSet
		self._killerObservations[player] = nil

		for sub, _ in pairs(subSet) do
			sub:Complete()
		end

		-- Hope we don't recreate this!
		assert(not self._killerObservations[player], "Killer observations recreated")
	end))
end

--[=[
	Observes killer reports for the given player

	@param player Player
	@return Observable<DeathReport>
]=]
function DeathReportService:ObserveKillerReports(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return Observable.new(function(sub)
		local maid = Maid.new()

		self._killerObservations[player] = self._killerObservations[player] or {}
		self._killerObservations[player][sub] = true

		if Table.count(self._killerObservations) >= 100 then
			warn("[DeathReportService] - self._killerObservations may be memory leaking, over 100 observations")
		end

		maid:GiveTask(function()
			sub:Complete()

			local playerSubs = self._killerObservations[player]
			if not playerSubs then -- already gone!
				return
			end

			playerSubs[sub] = nil
			if not next(playerSubs) then
				self._killerObservations[player] = nil
			end
		end)

		return maid
	end)
end

--[=[
	Observes death reports for the given player

	@param player Player
	@return Observable<DeathReport>
]=]
function DeathReportService:ObserveDeathReports(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return Observable.new(function(sub)
		local maid = Maid.new()

		self._deathObservations[player] = self._deathObservations[player] or {}
		self._deathObservations[player][sub] = true

		if Table.count(self._deathObservations) >= 100 then
			warn("[DeathReportService] - self._deathObservations may be memory leaking, over 100 observations")
		end

		maid:GiveTask(function()
			sub:Complete()

			local playerSubs = self._deathObservations[player]
			if not playerSubs then -- already gone!
				return
			end

			playerSubs[sub] = nil
			if not next(playerSubs) then
				self._deathObservations[player] = nil
			end
		end)

		return maid
	end)
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

	if report.killer then
		-- dispatch subscriptions!
		local subSet = self._killerObservations[report.killer]
		if subSet then
			for sub, _ in pairs(subSet) do
				sub:Fire(report)
			end
		end
	end

	if report.player then
		-- dispatch subscriptions!
		local subSet = self._deathObservations[report.player]
		if subSet then
			for sub, _ in pairs(subSet) do
				sub:Fire(report)
			end
		end
	end

	-- Send to all clients
	self._remoteEvent:FireAllClients(report)
end

function DeathReportService:Destroy()
	self._maid:DoCleaning()
end

return DeathReportService