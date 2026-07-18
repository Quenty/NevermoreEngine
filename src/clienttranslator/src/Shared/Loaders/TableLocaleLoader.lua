--!strict
--[=[
	Loads a table-driven translator's already-decoded, in-memory entries. The data is a
	single locale already in memory, so there is no per-locale laziness -- every entry
	point queues the full set once.

	Shares the loader surface (LoadSourceLocale / LoadLocale / LoadAllLocales) with
	[InstanceLocaleLoader] so [JSONTranslator] can drive either the same way.

	@class TableLocaleLoader
]=]

local TableLocaleLoader = {}
TableLocaleLoader.ClassName = "TableLocaleLoader"
TableLocaleLoader.__index = TableLocaleLoader

export type Writer = {
	SetEntryValue: (
		self: any,
		translationKey: string,
		source: string,
		context: string,
		localeId: string,
		text: string
	) -> (),
	SetEntryExample: (self: any, translationKey: string, source: string, context: string, example: string) -> (),
}

export type TableLocaleLoader = typeof(setmetatable(
	{} :: {
		_entries: { any },
		_loaded: boolean,
	},
	{} :: typeof({ __index = TableLocaleLoader })
))

--[=[
	@param entries { any } -- already-decoded localization entries
	@return TableLocaleLoader
]=]
function TableLocaleLoader.new(entries: { any }): TableLocaleLoader
	assert(type(entries) == "table", "Bad entries")

	local self = setmetatable({}, TableLocaleLoader)

	self._entries = entries
	self._loaded = false

	return self :: any
end

--[=[
	Queues the entries. See [TableLocaleLoader].
	@param writer Writer
]=]
function TableLocaleLoader.LoadSourceLocale(self: TableLocaleLoader, writer: Writer)
	self:_load(writer)
end

--[=[
	Queues the entries. See [TableLocaleLoader].
	@param writer Writer
]=]
function TableLocaleLoader.LoadAllLocales(self: TableLocaleLoader, writer: Writer)
	self:_load(writer)
end

--[=[
	Queues the entries. In-memory data is fully loaded up front, so there is nothing to
	defer for a specific locale.

	@param _localeId string
	@param writer Writer
]=]
function TableLocaleLoader.LoadLocale(self: TableLocaleLoader, _localeId: string, writer: Writer)
	self:_load(writer)
end

function TableLocaleLoader._load(self: TableLocaleLoader, writer: Writer)
	if self._loaded then
		return
	end
	self._loaded = true

	for _, item in self._entries do
		for localeId, text in item.Values do
			writer:SetEntryValue(item.Key, item.Source, item.Context, localeId, text)
		end
		writer:SetEntryExample(item.Key, item.Source, item.Context, item.Example)
	end
end

return TableLocaleLoader
