--!strict
--[=[
	Loads a table-driven translator's already-decoded, in-memory entries. The data is a
	single locale already in memory, so there is no per-locale laziness -- every entry
	point queues the full set once.

	Writes land on the [TranslatorService] resolved from the [ServiceBag] passed to the
	constructor. Shares the loader surface (LoadSourceLocale / LoadLocale / LoadAllLocales)
	with [InstanceLocaleLoader] so [JSONTranslator] can drive either the same way.

	@class TableLocaleLoader
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")
local TranslatorService = require("TranslatorService")

local TableLocaleLoader = {}
TableLocaleLoader.ClassName = "TableLocaleLoader"
TableLocaleLoader.__index = TableLocaleLoader

export type TableLocaleLoader = typeof(setmetatable(
	{} :: {
		_translatorService: TranslatorService.TranslatorService,
		_entries: { any },
		_loaded: boolean,
	},
	{} :: typeof({ __index = TableLocaleLoader })
))

--[=[
	@param serviceBag ServiceBag -- provides the [TranslatorService] writes land on
	@param entries { any } -- already-decoded localization entries
	@return TableLocaleLoader
]=]
function TableLocaleLoader.new(serviceBag: ServiceBag.ServiceBag, entries: { any }): TableLocaleLoader
	assert(serviceBag, "Bad serviceBag")
	assert(type(entries) == "table", "Bad entries")

	local self = setmetatable({}, TableLocaleLoader)

	self._translatorService = serviceBag:GetService(TranslatorService) :: any
	self._entries = entries
	self._loaded = false

	return self :: any
end

--[=[
	Queues the entries. See [TableLocaleLoader].
]=]
function TableLocaleLoader.LoadSourceLocale(self: TableLocaleLoader)
	self:_load()
end

--[=[
	Queues the entries. See [TableLocaleLoader].
]=]
function TableLocaleLoader.LoadAllLocales(self: TableLocaleLoader)
	self:_load()
end

--[=[
	Queues the entries. In-memory data is fully loaded up front, so there is nothing to
	defer for a specific locale.

	@param _localeId string
]=]
function TableLocaleLoader.LoadLocale(self: TableLocaleLoader, _localeId: string)
	self:_load()
end

function TableLocaleLoader._load(self: TableLocaleLoader)
	if self._loaded then
		return
	end
	self._loaded = true

	for _, item in self._entries do
		for localeId, text in item.Values do
			self._translatorService:SetEntryValue(item.Key, item.Source, item.Context, localeId, text)
		end
		self._translatorService:SetEntryExample(item.Key, item.Source, item.Context, item.Example)
	end
end

return TableLocaleLoader
