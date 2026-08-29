--!strict
--[=[
	Localization export command.

	| Command | What it does |
	| --- | --- |
	| `prepare-localization-export` | Loads every locale of every translator into this server's table |

	Translators load lazily -- the source language, plus whichever one a player reads -- so no
	realm ever assembles the full set on its own. That is the point: a game with a dozen
	languages should not carry eleven it will never show. The CSV export is the one job that
	needs all of them in one table at one moment, so it asks for them here.

	Run it, then save `GeneratedJSONTable_Server` as CSV -- see [JSONTranslator] for the rest of
	the upload steps.

	@server
	@class TranslatorCmdrService
]=]

local require = require(script.Parent.loader).load(script)

local CmdrService = require("CmdrService")
local CmdrTypes = require("CmdrTypes")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local TranslatorService = require("TranslatorService")

local TranslatorCmdrService = {}
TranslatorCmdrService.ServiceName = "TranslatorCmdrService"

type CommandContext = CmdrTypes.CommandContext

export type TranslatorCmdrService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_cmdrService: any,
		_translatorService: TranslatorService.TranslatorService,
	},
	{} :: typeof({ __index = TranslatorCmdrService })
))

function TranslatorCmdrService.Init(self: TranslatorCmdrService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._cmdrService = self._serviceBag:GetService(CmdrService)

	-- Internal
	self._translatorService = self._serviceBag:GetService(TranslatorService) :: any
end

function TranslatorCmdrService.Start(self: TranslatorCmdrService): ()
	self._maid:GivePromise(self._cmdrService:PromiseCmdr()):Then(function()
		self:_registerCommands()
	end)
end

function TranslatorCmdrService._registerCommands(self: TranslatorCmdrService): ()
	self._cmdrService:RegisterCommand({
		Name = "prepare-localization-export",
		Description = "Loads every locale of every translator into GeneratedJSONTable_Server so it can be saved as CSV and uploaded.",
		Group = "Localization",
		Args = {},
	}, function(_context: CommandContext)
		return self:_prepareExport()
	end)
end

-- Yields until the table has settled rather than reporting on a batch still in flight: the
-- next thing the operator does is read the table by hand, so "done" has to mean readable.
function TranslatorCmdrService._prepareExport(self: TranslatorCmdrService): string
	local isFulfilled = self._translatorService:PromiseLoadAllLocales():Yield()
	if not isFulfilled then
		return "Failed to load every locale. Check the output for which file could not be reached."
	end

	local localizationTable = self._translatorService:GetLocalizationTable()

	return string.format(
		"Loaded every locale. %s now holds %d entries -- find it under LocalizationService, right click, Save as CSV.",
		localizationTable.Name,
		#localizationTable:GetEntries()
	)
end

function TranslatorCmdrService.Destroy(self: TranslatorCmdrService): ()
	self._maid:DoCleaning()
end

return TranslatorCmdrService
