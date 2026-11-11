--!strict
--[=[
	Ragdoll admin commands.

	| Command | What it does |
	| --- | --- |
	| `ragdoll` | Ragdolls players |
	| `unragdoll` | Takes players out of a ragdoll |

	Both take a list of players, so `ragdoll *` reaches everyone in the server as readily as a single
	username does, and both act on the humanoid of each player's current character. A player without
	one is reported and skipped, so one dead or loading player never hides what happened to the rest.

	@server
	@class RagdollCmdrService
]=]

local require = require(script.Parent.loader).load(script)

local CharacterUtils = require("CharacterUtils")
local CmdrService = require("CmdrService")
local CmdrTypes = require("CmdrTypes")
local Maid = require("Maid")
local PlayerUtils = require("PlayerUtils")
local Ragdoll = require("Ragdoll")
local ServiceBag = require("ServiceBag")

local RagdollCmdrService = {}
RagdollCmdrService.ServiceName = "RagdollCmdrService"

type CommandContext = CmdrTypes.CommandContext

export type RagdollCmdrService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_cmdrService: any,
		_ragdollBinder: typeof(Ragdoll),
	},
	{} :: typeof({ __index = RagdollCmdrService })
))

function RagdollCmdrService.Init(self: RagdollCmdrService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._cmdrService = self._serviceBag:GetService(CmdrService)

	-- Internal
	self._ragdollBinder = self._serviceBag:GetService(Ragdoll)
end

function RagdollCmdrService.Start(self: RagdollCmdrService): ()
	self._maid:GivePromise(self._cmdrService:PromiseCmdr()):Then(function()
		self:_registerCommands()
	end)
end

-- Shared so the "which players" argument reads the same in both commands.
local PLAYERS_ARG_DESCRIPTION = "Players to act on (e.g. . for yourself, * for everyone here, or a username)."

function RagdollCmdrService._registerCommands(self: RagdollCmdrService): ()
	self._cmdrService:RegisterCommand({
		Name = "ragdoll",
		Description = "Ragdolls players. They stay ragdolled until unragdolled, unless the game unragdolls them itself (see UnragdollAutomatically).",
		Group = "Ragdoll",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
		},
	}, function(_context: CommandContext, players: { Player })
		return self:_setRagdolled(players, true)
	end)

	self._cmdrService:RegisterCommand({
		Name = "unragdoll",
		Description = "Takes players out of a ragdoll, whether they were ragdolled by hand or by falling or dying.",
		Group = "Ragdoll",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
		},
	}, function(_context: CommandContext, players: { Player })
		return self:_setRagdolled(players, false)
	end)
end

-- Reports a line per player, since the interesting cases (already ragdolled, no character) are
-- per-player and an admin running this on everyone still wants to see them.
function RagdollCmdrService._setRagdolled(self: RagdollCmdrService, players: { Player }, isRagdolled: boolean): string
	if #players == 0 then
		return "No players to act on."
	end

	local lines: { string } = {}

	for _, player in players do
		local name = PlayerUtils.formatName(player)
		local humanoid = CharacterUtils.getPlayerHumanoid(player)

		if not humanoid then
			table.insert(lines, `{name} has no character.`)
			continue
		end

		local wasRagdolled = self._ragdollBinder:Get(humanoid) ~= nil
		if wasRagdolled == isRagdolled then
			table.insert(lines, if isRagdolled then `{name} is already ragdolled.` else `{name} is not ragdolled.`)
			continue
		end

		if isRagdolled then
			self._ragdollBinder:Bind(humanoid)
			table.insert(lines, `Ragdolled {name}.`)
		else
			self._ragdollBinder:Unbind(humanoid)
			table.insert(lines, `Unragdolled {name}.`)
		end
	end

	return table.concat(lines, "\n")
end

function RagdollCmdrService.Destroy(self: RagdollCmdrService): ()
	self._maid:DoCleaning()
end

return RagdollCmdrService
