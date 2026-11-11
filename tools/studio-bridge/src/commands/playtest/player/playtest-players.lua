--!strict
--[=[
	Action that reads and changes the players of a running playtest.

	StudioTestService only adds players from the server DataModel of a
	multiplayer test, so `list`, `add` and `remove` target the server session.
	`leave` targets a player's client session: it closes that player's Studio
	process, which kicking from the server leaves open.

	Request: `{ type: "playtestPlayers", payload: { op: "list" } }`
	Request: `{ type: "playtestPlayers", payload: { op: "add", count, timeoutSec } }`
	Request: `{ type: "playtestPlayers", payload: { op: "remove", kick: { name }, names: { name }, timeoutSec } }`
	Request: `{ type: "playtestPlayers", payload: { op: "leave" } }`
	Response: `{ type: "playtestPlayersResult", payload: { players?, remaining? } }`

	- `add` answers once the players have joined, or with those that joined by
	  the timeout.
	- `remove` kicks the players in `kick`, then answers once every player in
	  `names` has left, with `remaining` listing any still there at the timeout.

	@class PlaytestPlayersAction
]=]

local Players = game:GetService("Players")

local POLL_INTERVAL_SEC = 0.25

local PlaytestPlayersAction = {}

export type PlayerInfo = {
	name: string,
	userId: number,
	displayName: string,
}

--[=[
	Registers the `playtestPlayers` handler.
]=]
function PlaytestPlayersAction.register(router: any)
	router:setResponseType("playtestPlayers", "playtestPlayersResult")
	router:register("playtestPlayers", function(payload: { [string]: any }, _requestId: string, _sessionId: string)
		local op = payload.op
		if op == "list" then
			return { players = PlaytestPlayersAction._list() }
		elseif op == "add" then
			return { players = PlaytestPlayersAction._addAsync(payload.count, payload.timeoutSec) }
		elseif op == "remove" then
			return { remaining = PlaytestPlayersAction._removeAsync(payload.kick, payload.names, payload.timeoutSec) }
		elseif op == "leave" then
			task.defer(function()
				(game:GetService("StudioTestService") :: any):LeaveTest()
			end)
			return {}
		end
		error(`Unknown playtestPlayers op: {tostring(op)}`)
	end)
end

function PlaytestPlayersAction._info(player: Player): PlayerInfo
	return { name = player.Name, userId = player.UserId, displayName = player.DisplayName }
end

function PlaytestPlayersAction._list(): { PlayerInfo }
	local players = {}
	for _, player in Players:GetPlayers() do
		table.insert(players, PlaytestPlayersAction._info(player))
	end
	return players
end

function PlaytestPlayersAction._addAsync(count: any, timeoutSec: any): { PlayerInfo }
	if type(count) ~= "number" or count < 1 or type(timeoutSec) ~= "number" then
		error("add needs a count of at least 1 and a timeoutSec")
	end

	local before: { [Player]: boolean } = {}
	for _, player in Players:GetPlayers() do
		before[player] = true
	end

	(game:GetService("StudioTestService") :: any):AddPlayers(count)

	local deadline = os.clock() + timeoutSec
	local added: { PlayerInfo }
	repeat
		task.wait(POLL_INTERVAL_SEC)
		added = {}
		for _, player in Players:GetPlayers() do
			if not before[player] then
				table.insert(added, PlaytestPlayersAction._info(player))
			end
		end
	until #added >= count or os.clock() > deadline

	return added
end

function PlaytestPlayersAction._removeAsync(kick: any, names: any, timeoutSec: any): { string }
	if type(kick) ~= "table" or type(names) ~= "table" or type(timeoutSec) ~= "number" then
		error("remove needs kick, names and timeoutSec")
	end

	for _, name in kick do
		local player = Players:FindFirstChild(name)
		if player and player:IsA("Player") then
			player:Kick("Removed by studio-bridge")
		end
	end

	local deadline = os.clock() + timeoutSec
	local remaining: { string }
	repeat
		remaining = {}
		for _, name in names do
			if Players:FindFirstChild(name) then
				table.insert(remaining, name)
			end
		end
		if #remaining > 0 then
			task.wait(POLL_INTERVAL_SEC)
		end
	until #remaining == 0 or os.clock() > deadline

	return remaining
end

return PlaytestPlayersAction
