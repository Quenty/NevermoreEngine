--!strict
--[=[
	Loads a table-driven translator's already-decoded, in-memory entries. The data is a
	single locale already in memory, so there is no per-locale laziness -- every entry
	point queues the full set once.

	Registered as a service by the [JSONTranslator] that owns it, and writes land on the
	[TranslatorService] resolved from the same bag. Shares the loader surface
	(LoadSourceLocale / LoadLocale / LoadAllLocales) with [InstanceLocaleLoader] so
	[JSONTranslator] can drive either the same way.

	@class TableLocaleLoader
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")
local TranslatorService = require("TranslatorService")

local TableLocaleLoader = setmetatable({}, BaseObject)
TableLocaleLoader.ClassName = "TableLocaleLoader"
TableLocaleLoader.__index = TableLocaleLoader

export type TableLocaleLoader = typeof(setmetatable(
	{} :: {
		ServiceName: string,
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_translatorService: TranslatorService.TranslatorService,
		_entries: { any },
		_loaded: boolean,
	},
	{} :: typeof({ __index = TableLocaleLoader })
))

--[=[
	Constructs a new [TableLocaleLoader]. Register it on the [ServiceBag] that provides the
	[TranslatorService] its writes land on.

	@param translatorName string
	@param entries { any } -- already-decoded localization entries
	@return TableLocaleLoader
]=]
function TableLocaleLoader.new(translatorName: string, entries: { any }): TableLocaleLoader
	assert(type(translatorName) == "string", "Bad translatorName")
	assert(type(entries) == "table", "Bad entries")

	local self: TableLocaleLoader = setmetatable({} :: any, TableLocaleLoader)

	self.ServiceName = translatorName .. "LocaleLoader"
	self._entries = entries
	self._loaded = false

	return self
end

--[=[
	Initializes the loader. Should be done via [ServiceBag].

	@param serviceBag ServiceBag
]=]
function TableLocaleLoader.Init(self: TableLocaleLoader, serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._translatorService = serviceBag:GetService(TranslatorService) :: any
end

--[=[
	Queues the entries. See [TableLocaleLoader].
]=]
function TableLocaleLoader.LoadSourceLocale(self: TableLocaleLoader)
	self:_load()
end

--[=[
	Queues the entries and resolves. In-memory data has nothing to fetch, so the source
	locale is available the moment it is asked for. Mirrors
	[InstanceLocaleLoader.PromiseSourceLocale] so [JSONTranslator] can await either.

	@return Promise<()>
]=]
function TableLocaleLoader.PromiseSourceLocale(self: TableLocaleLoader): Promise.Promise<()>
	self:_load()

	return Promise.resolved()
end

--[=[
	Queues the entries. See [TableLocaleLoader].
]=]
function TableLocaleLoader.LoadAllLocales(self: TableLocaleLoader)
	self:_load()
end

--[=[
	Queues the entries and resolves. Mirrors [InstanceLocaleLoader.PromiseAllLocales] so
	[TranslatorService.PromiseLoadAllLocales] can drive either.

	@return Promise<()>
]=]
function TableLocaleLoader.PromiseAllLocales(self: TableLocaleLoader): Promise.Promise<()>
	self:_load()

	return Promise.resolved()
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
