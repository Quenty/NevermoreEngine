--[=[
	@class RxTeamUtils
]=]

local require = require(script.Parent.loader).load(script)

local Teams = game:GetService("Teams")

local Observable = require("Observable")
local Maid = require("Maid")
local Brio = require("Brio")
local RxBrioUtils = require("RxBrioUtils")

local RxTeamUtils = {}

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

function RxTeamUtils.observePlayersForTeamColorBrio(teamColor)
	assert(typeof(teamColor) == "BrickColor", "Bad teamColor")

	return RxTeamUtils.observeTeamsForColorBrio(teamColor):Pipe({
		-- NOTE: Switch map here means we get a subtle bug, but alternative is duplicate players if there's 2 teams
		-- with the same color so no great solution here.
		RxBrioUtils.switchMapBrio(function(team)
			return RxTeamUtils.observePlayersForTeamBrio(team)
		end)
	})
end

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