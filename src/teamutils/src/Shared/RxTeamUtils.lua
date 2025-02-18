--[=[
	Helper methods involving teams on Roblox.
	@class RxTeamUtils
]=]

local require = require(script.Parent.loader).load(script)

local Teams = game:GetService("Teams")
local Players = game:GetService("Players")

local Observable = require("Observable")
local Maid = require("Maid")
local Brio = require("Brio")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local Rx = require("Rx")

local RxTeamUtils = {}

function RxTeamUtils.observePlayerTeam(player)
	return Rx.combineLatest({
		team = RxInstanceUtils.observeProperty(player, "Team");
		neutral = RxInstanceUtils.observeProperty(player, "Neutral")
	}):Pipe({
		Rx.map(function(state)
			if state.neutral then
				return nil
			end

			return state.team
		end)
	})
end

function RxTeamUtils.observePlayerTeamColor(player)
	return RxTeamUtils.observePlayerTeam(player):Pipe({
		Rx.switchMap(function(team)
			if team then
				return RxInstanceUtils.observeProperty(team, "TeamColor")
			else
				return Rx.of(nil)
			end
		end)
	})
end

--[=[
	Observes all players on a taem.

	@param team Team
	@return Observable<Brio<Player>>
]=]
function RxTeamUtils.observePlayersForTeamBrio(team)
	assert(typeof(team) == "Instance" and team:IsA("Team"), "Bad team")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handlePlayer(player)
			local brio = Brio.new(player)
			maid[player] = brio

			sub:Fire(brio)
		end

		maid:GiveTask(team.PlayerAdded:Connect(handlePlayer))
		maid:GiveTask(team.PlayerRemoved:Connect(function(player)
			maid[player] = nil
		end))

		for _, player in pairs(team:GetPlayers()) do
			handlePlayer(player)
		end

		return maid
	end)
end

--[=[
	Observes all enemy players for a team color

	@param teamColor BrickColor
	@return Observable<Brio<Player>>
]=]
function RxTeamUtils.observeEnemyTeamColorPlayersBrio(teamColor)
	assert(typeof(teamColor) == "BrickColor", "Bad teamColor")

	return Observable.new(function(sub)
		local topMaid = Maid.new()

		local function handlePlayerTeamChanged(playerMaid, player)
			if player.Team and player.Team.TeamColor.Number == teamColor.Number then
				playerMaid[player] = nil
			else
				local brio = Brio.new(player)
				playerMaid[player] = brio
				sub:Fire(brio)
			end
		end

		local function handlePlayer(player)
			local maid = Maid.new()

			handlePlayerTeamChanged(maid, player)
			maid:GiveTask(player:GetPropertyChangedSignal("Team"):Connect(function()
				handlePlayerTeamChanged(maid, player)
			end))

			topMaid[player] = maid
		end

		topMaid:GiveTask(Players.PlayerAdded:Connect(handlePlayer))
		topMaid:GiveTask(Players.PlayerRemoving:Connect(function(player)
			topMaid[player] = nil
		end))

		for _, player in pairs(Players:GetPlayers()) do
			handlePlayer(player)
		end

		return topMaid
	end)
end


--[=[
	Observes all players for a team color (given they have a team)

	@param teamColor BrickColor
	@return Observable<Brio<Player>>
]=]
function RxTeamUtils.observePlayersForTeamColorBrio(teamColor)
	assert(typeof(teamColor) == "BrickColor", "Bad teamColor")

	return RxTeamUtils.observeTeamsForColorBrio(teamColor):Pipe({
		-- NOTE: Switch map here means we get a subtle bug, but alternative is duplicate players if there's 2 teams
		-- with the same color so no great solution here.
		RxBrioUtils.switchMapBrio(function(team)
			return RxTeamUtils.observePlayersForTeamBrio(team)
		end);
	})
end

--[=[
	Observes all teams for a given color

	@param teamColor BrickColor
	@return Observable<Brio<Team>>
]=]
function RxTeamUtils.observeTeamsForColorBrio(teamColor)
	assert(typeof(teamColor) == "BrickColor", "Bad teamColor")

	return Observable.new(function(sub)
		local topMaid = Maid.new()

		topMaid:GiveTask(RxTeamUtils.observeTeamsBrio():Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid = brio:ToMaid()
			local team = brio:GetValue()

			local function update()
				if team.TeamColor.Number == teamColor.Number then
					local result = Brio.new(team)
					maid._current = result

					sub:Fire(result)
				else
					maid._current = nil
				end
			end
			team:GetPropertyChangedSignal("TeamColor"):Connect(update)
			update()
		end))

		return topMaid
	end)
end

--[=[
	Observes all teams in the game (In Teams service)

	@return Observable<Brio<Team>>
]=]
function RxTeamUtils.observeTeamsBrio()
	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleTeam(team)
			if team:IsA("Team") then
				local brio = Brio.new(team)
				maid[team] = brio

				sub:Fire(brio)
			end
		end

		maid:GiveTask(Teams.ChildAdded:Connect(handleTeam))
		maid:GiveTask(Teams.ChildRemoved:Connect(function(inst)
			maid[inst] = nil
		end))

		for _, team in pairs(Teams:GetTeams()) do
			handleTeam(team)
		end

		return maid
	end)
end

return RxTeamUtils