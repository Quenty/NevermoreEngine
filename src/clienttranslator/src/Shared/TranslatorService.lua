--!strict
--[=[
	Handles selecting the right locale/translator for Studio, and Roblox games.

	@class TranslatorService
]=]

local require = require(script.Parent.loader).load(script)

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")

local LocalizationServiceUtils = require("LocalizationServiceUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local ResolveLocaleUtils = require("ResolveLocaleUtils")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")
local TieRealms = require("TieRealms")
local ValueObject = require("ValueObject")

local TranslatorService = {}
TranslatorService.ServiceName = "TranslatorService"

-- How many entries re-serializing costs about as much as one invalidation of the engine's
-- cached table contents. Every mutating call to a LocalizationTable -- SetEntries and
-- SetEntryValue alike -- invalidates that cache, raises a property change, and fires the
-- engine's retranslation signal; on top of that SetEntries re-serializes every entry in the
-- table, while SetEntryValue touches only one. So the surgical path wins while the batch is
-- small *relative to the table it writes into*: rewriting 20 entries of 20 is a full rebuild
-- either way, rewriting 20 of 8000 is not. See docs/design.md ("Writes are batched").
local INVALIDATION_ENTRY_COST = 100

-- An accumulated localization entry delta, merged into the table on flush along with the rest
-- of the frame's batch.
type PendingEntry = {
	Key: string,
	Source: string,
	Context: string,
	Example: string?,
	Values: { [string]: string },
}

-- Pending deltas indexed by translation key. A LocalizationTable keys its entries by the
-- translation key alone -- SetEntries rejects two entries that share a key even when their
-- source/context differ, and SetEntryValue overwrites in place -- so we hold at most one
-- pending delta per key. A later write for the same key with a different source/context
-- overwrites the source/context (last write wins) rather than queueing a second entry, which
-- would make the flush feed SetEntries a duplicate key and throw. Keying by translation key
-- also lets a single-key flush ([TranslatorService.FlushEntryForKey]) find its entry in O(1).
type PendingEntries = { [string]: PendingEntry }

-- One subscriber to a key's readiness. Flagged rather than only removed from its list, so a
-- fan-out already in progress over a copy of that list can skip it.
type ReadyObserver = {
	Callback: (boolean) -> (),
	Disconnected: boolean,
}

-- An entry as the LocalizationTable stores it (the shape GetEntries returns and SetEntries
-- takes).
type LocalizationEntry = {
	Key: string,
	Source: string,
	Context: string,
	Example: string,
	Values: { [string]: string },
}

-- What the localization table currently holds, indexed both ways: the array is what a bulk
-- SetEntries writes back, the map is how a write finds the entry for its key.
type EntryCache = {
	List: { LocalizationEntry },
	ByKey: { [string]: LocalizationEntry },
}

-- One targeted table write the flush still owes: a locale's value, or (LocaleId nil) the
-- entry's example.
type PendingWrite = {
	Entry: LocalizationEntry,
	LocaleId: string?,
}

-- Mirrors of the localization tables' contents, so neither a write nor a flush has to read
-- the table back. GetEntries copies and re-materializes every entry in the table, so calling
-- it per flush makes a frame that touches one key cost O(table) -- exactly the cost the
-- batching exists to avoid.
--
-- Keyed by the table itself, and shared across TranslatorService instances rather than held
-- per service, because the table is shared: it is found by realm-scoped name, so a second
-- service bag in the same realm (a story, a test) writes into the same instance and a
-- private mirror would go stale behind it. Weak so a destroyed table's mirror goes with it.
--
-- This assumes this package is the only writer of GeneratedJSONTable_*, which the design
-- already requires (everything goes through TranslatorService).
local entryCachesByTable: { [LocalizationTable]: EntryCache } = setmetatable({}, { __mode = "k" }) :: any

export type TranslatorService = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_serviceBag: ServiceBag.ServiceBag,
		_tieRealmService: TieRealmService.TieRealmService,
		_translator: ValueObject.ValueObject<Translator>,
		_localizationTable: LocalizationTable?,
		_pendingTranslatorPromise: Promise.Promise<Translator>?,
		_forcedLocaleId: ValueObject.ValueObject<string?>,
		_localeIdValue: ValueObject.ValueObject<string>?,
		_loadedPlayerObservable: Observable.Observable<Player>?,
		_loadedPlayer: Player?,
		_pendingEntries: PendingEntries,
		_readyObservers: { [string]: { ReadyObserver } },
		_isDestroyed: boolean,
		_flushScheduled: boolean,
		_pendingFlushPromise: Promise.Promise<()>?,
		_localizationWriteCount: number,
		_localizationRebuildCount: number,
	},
	{} :: typeof({ __index = TranslatorService })
))

function TranslatorService.Init(self: TranslatorService, serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._tieRealmService = serviceBag:GetService(TieRealmService) :: any

	self._pendingEntries = {}
	self._readyObservers = {}
	self._isDestroyed = false
	self._flushScheduled = false
	self._localizationWriteCount = 0
	self._localizationRebuildCount = 0

	self._forcedLocaleId = self._maid:Add(ValueObject.new(nil))

	self._translator = self._maid:Add(ValueObject.new(nil))
	self._translator:Mount(self:_observeTranslatorImpl())
end

function TranslatorService.GetLocalizationTable(self: TranslatorService): LocalizationTable
	if self._localizationTable then
		return self._localizationTable
	end

	local localizationTableName = self:_getLocalizationTableName()
	local localizationTable = LocalizationService:FindFirstChild(localizationTableName)

	if not localizationTable then
		localizationTable = Instance.new("LocalizationTable")
		localizationTable.Name = localizationTableName
		localizationTable.Parent = LocalizationService
	end

	self._localizationTable = localizationTable
	return localizationTable
end

function TranslatorService._getLocalizationTableName(self: TranslatorService): string
	if self._tieRealmService:GetTieRealm() == TieRealms.SERVER then
		return "GeneratedJSONTable_Server"
	else
		return "GeneratedJSONTable_Client"
	end
end

--[=[
	Forces the locale id used for translation, overriding the inferred player/Roblox
	locale. Pass nil to clear the override and fall back to the inferred locale. Useful
	for an in-game language selector.

	@param localeId string?
]=]
function TranslatorService.SetForcedLocaleId(self: TranslatorService, localeId: string?)
	assert(localeId == nil or type(localeId) == "string", "Bad localeId")

	self._forcedLocaleId.Value = localeId
end

--[=[
	Queues a localization table entry value write. Writes are batched and flushed
	together at the end of the frame (via `task.defer`) instead of being applied
	synchronously, so a burst of translators loading does not each pay the cost of
	mutating (and re-replicating) the shared localization table in the load path.

	A key is therefore not readable the instant it is registered. Gate reads on
	[TranslatorService.ObserveIsTranslationReady], which tracks the key you are about to read
	rather than whichever batch happened to be pending.

	Registering what the table already holds is free: the write is dropped before it queues, so
	it neither schedules a flush nor takes the key not-ready. Re-registering unchanged text is
	the common case rather than the exception.

	@param translationKey string
	@param source string
	@param context string
	@param localeId string
	@param text string
]=]
function TranslatorService.SetEntryValue(
	self: TranslatorService,
	translationKey: string,
	source: string,
	context: string,
	localeId: string,
	text: string
)
	if self._isDestroyed then
		-- Dropped rather than queued: nothing will flush it, and a queued entry would pin the
		-- key not-ready forever for anything that asks afterwards.
		return
	end

	if self:_isEntryValueCurrent(translationKey, source, context, localeId, text) then
		return
	end

	local entry, becamePending = self:_getPendingEntry(translationKey, source, context)
	entry.Values[localeId] = text
	self:_scheduleFlush()

	-- Announced only once the value is stored and the flush is scheduled, so a subscriber
	-- reacting to "not ready" sees state that agrees with it.
	if becamePending then
		self:_fireTranslationReady(translationKey)
	end
end

--[=[
	Queues a localization table entry example write. See [TranslatorService.SetEntryValue].

	@param translationKey string
	@param source string
	@param context string
	@param example string
]=]
function TranslatorService.SetEntryExample(
	self: TranslatorService,
	translationKey: string,
	source: string,
	context: string,
	example: string
)
	if self._isDestroyed then
		return
	end

	if self:_isEntryExampleCurrent(translationKey, source, context, example) then
		return
	end

	local entry, becamePending = self:_getPendingEntry(translationKey, source, context)
	entry.Example = example
	self:_scheduleFlush()

	if becamePending then
		self:_fireTranslationReady(translationKey)
	end
end

-- Returns the pending delta for a key, and whether this call is what made the key pending
-- (the caller announces that, once the write it is making has actually been stored).
function TranslatorService._getPendingEntry(
	self: TranslatorService,
	translationKey: string,
	source: string,
	context: string
): (PendingEntry, boolean)
	local entry = self._pendingEntries[translationKey]
	if not entry then
		local newEntry: PendingEntry = {
			Key = translationKey,
			Source = source,
			Context = context,
			Values = {},
		}
		self._pendingEntries[translationKey] = newEntry
		return newEntry, true
	else
		-- The table keys entries by translation key alone, so a second write for the same key
		-- with a different source/context overwrites in place (as SetEntryValue would) rather
		-- than queueing a duplicate that SetEntries would reject. Accumulated values are kept.
		entry.Source = source
		entry.Context = context
	end

	return entry, false
end

-- The mirror of a table's entries, built from the table the first time anything needs it.
function TranslatorService._getEntryCache(_self: TranslatorService, localizationTable: LocalizationTable): EntryCache
	local existing = entryCachesByTable[localizationTable]
	if existing then
		return existing
	end

	local list: { LocalizationEntry } = localizationTable:GetEntries() :: any
	local byKey: { [string]: LocalizationEntry } = {}
	for _, entry in list do
		byKey[entry.Key] = entry
	end

	local cache: EntryCache = { List = list, ByKey = byKey }
	entryCachesByTable[localizationTable] = cache
	return cache
end

-- Whether the table already holds exactly this value, making the write nothing but cost.
--
-- Re-registering unchanged text is the common case rather than the exception: minting a
-- translation key ([JSONTranslator.ToTranslationKey]) registers its source text every time a
-- label is built, and a loader re-queues a locale it has already loaded. Queuing such a write
-- would schedule a flush, and -- because the key goes not-ready and back -- drive a
-- re-translation pass through every reader of that key, all to write back what is there.
function TranslatorService._isEntryValueCurrent(
	self: TranslatorService,
	translationKey: string,
	source: string,
	context: string,
	localeId: string,
	text: string
): boolean
	-- A key with a delta queued is mid-change; the flush decides what the table ends up with.
	if self._pendingEntries[translationKey] then
		return false
	end

	local entry = self:_getEntryCache(self:GetLocalizationTable()).ByKey[translationKey]
	if not entry then
		return false
	end

	-- Source and context are part of what a write would land, so a change in either is still
	-- a change even when the text matches.
	return entry.Source == source and entry.Context == context and entry.Values[localeId] == text
end

-- Whether the table already holds exactly this example. See [TranslatorService._isEntryValueCurrent].
function TranslatorService._isEntryExampleCurrent(
	self: TranslatorService,
	translationKey: string,
	source: string,
	context: string,
	example: string
): boolean
	if self._pendingEntries[translationKey] then
		return false
	end

	local entry = self:_getEntryCache(self:GetLocalizationTable()).ByKey[translationKey]
	if not entry then
		return false
	end

	return entry.Source == source and entry.Context == context and entry.Example == example
end

--[=[
	Returns a promise that resolves once all currently-queued localization writes
	have been flushed to the table. Resolves immediately if nothing is pending.

	This answers for the batch pending when it is called, which is not necessarily the batch
	carrying the data a reader wants: writes queued while this flush resolves land in the
	next one. Gate reads on [TranslatorService.ObserveIsTranslationReady] instead -- this is for
	callers that want the current batch settled, such as tests.

	@return Promise
]=]
function TranslatorService.PromiseEntriesWritten(self: TranslatorService): Promise.Promise<()>
	if not self._flushScheduled then
		return Promise.resolved()
	end

	return assert(self._pendingFlushPromise, "Flush scheduled without a pending promise")
end

--[=[
	Whether a read of this key would see everything queued for it. False while the key has
	writes waiting on the end-of-frame flush.

	:::warning
	This is an implementation detail of the translation stack, exposed for diagnostics.
	Reading a translation through [JSONTranslator] already accounts for it.
	:::

	A key nothing has ever queued is ready: there is nothing pending to wait for, and a read
	should fall through to whatever the translators can offer rather than block forever.

	@param translationKey string
	@return boolean
]=]
function TranslatorService.IsTranslationReady(self: TranslatorService, translationKey: string): boolean
	assert(type(translationKey) == "string", "Bad translationKey")

	return self._pendingEntries[translationKey] == nil
end

--[=[
	Whether a read of this key **in this locale** would see everything queued for it. Narrower
	than [TranslatorService.IsTranslationReady], which is false while any locale is queued.

	:::warning
	This is an implementation detail of the translation stack, exposed for diagnostics.
	:::

	The distinction matters after a single-key flush ([TranslatorService.FlushEntryForKey]),
	which lands the locales a read can consult but leaves the entry queued for the rest. The
	key is readable in that locale while still not ready overall, so a failure to translate it
	is a real failure and worth reporting.

	@param translationKey string
	@param localeId string
	@return boolean
]=]
function TranslatorService.IsTranslationReadyForLocale(
	self: TranslatorService,
	translationKey: string,
	localeId: string
): boolean
	assert(type(translationKey) == "string", "Bad translationKey")
	assert(type(localeId) == "string", "Bad localeId")

	local entry = self._pendingEntries[translationKey]
	if not entry then
		return true
	end

	return entry.Values[localeId] == nil
end

--[=[
	Observes whether a read of this key would see everything queued for it, firing the
	current state immediately and again on every change.

	:::warning
	This is an implementation detail of the translation stack, exposed for diagnostics. Every
	way of reading a translation through [JSONTranslator] already waits for the key it reads,
	so consumers should not have to gate on this themselves.
	:::

	This is the reactive counterpart to the batching: writes are deliberately deferred to the
	end of the frame (see [TranslatorService.SetEntryValue]), so a reader that translates the
	instant a key is registered reads before the write lands. Rather than forcing the flush --
	which would defeat the batching that keeps a streaming-in game from writing the table
	thousands of times a frame -- [JSONTranslator] observes this and re-reads when it goes
	ready.

	Emissions are driven by the queue and flush directly, so nothing here yields.

	@param translationKey string
	@return Observable<boolean>
]=]
function TranslatorService.ObserveIsTranslationReady(
	self: TranslatorService,
	translationKey: string
): Observable.Observable<boolean>
	assert(type(translationKey) == "string", "Bad translationKey")

	return Observable.new(function(sub)
		-- Observers are held per key so queuing a write costs one lookup rather than a
		-- fan-out over every subscriber in the game.
		local observers = self._readyObservers[translationKey]
		if not observers then
			observers = {}
			self._readyObservers[translationKey] = observers
		end

		local observer: ReadyObserver = {
			Callback = function(isReady: boolean)
				sub:Fire(isReady)
			end,
			Disconnected = false,
		}
		table.insert(observers, observer)

		sub:Fire(self:IsTranslationReady(translationKey))

		return function()
			observer.Disconnected = true

			local index = table.find(observers, observer)
			if index then
				table.remove(observers, index)
			end

			-- Dropping the last observer's list keeps a game that observes many keys
			-- transiently from accumulating them.
			if #observers == 0 and self._readyObservers[translationKey] == observers then
				self._readyObservers[translationKey] = nil
			end
		end
	end) :: any
end

-- Tells a key's observers about a readiness change. The state is read per observer rather
-- than captured once: a handler earlier in the fan-out can re-queue the key, and handing the
-- observers after it a value that is already false would leave them believing the key landed.
function TranslatorService._fireTranslationReady(self: TranslatorService, translationKey: string)
	local observers = self._readyObservers[translationKey]
	if not observers then
		return
	end

	-- Over a copy, and skipping observers disconnected mid-fan-out: a handler is consumer
	-- code, and one that tears down UI can unsubscribe its siblings. The disconnected check
	-- has to be per observer rather than a membership test, since a handler may also
	-- subscribe -- a new observer has already been told the current state directly.
	for _, observer in table.clone(observers) do
		if not observer.Disconnected then
			-- Spawned so a raising handler cannot abort the fan-out and strand the rest.
			task.spawn(observer.Callback, self:IsTranslationReady(translationKey))
		end
	end
end

--[=[
	Flushes every pending localization write synchronously. This defeats the end-of-frame
	batching and pays the full table write cost, so it exists for tests that need the table
	settled immediately. Production synchronous reads should use
	[TranslatorService.FlushEntryForKey] to land just the key they need.
]=]
function TranslatorService.FlushEntriesForTesting(self: TranslatorService)
	if self._flushScheduled then
		self:_flushWrites()
	end
end

--[=[
	Lands only what a synchronous read of a single key actually needs, leaving the rest of
	the batch queued for the normal end-of-frame flush. This lets a synchronous read
	([JSONTranslator.FormatByKey]) guarantee the one key it reads is present without forcing
	-- and paying for -- the whole pending batch early.

	Only the locales a read can actually consult are landed (the example and every other
	locale in the entry stay queued), so a read costs a handful of targeted writes rather
	than one per locale in the entry.

	@param translationKey string
]=]
function TranslatorService.FlushEntryForKey(self: TranslatorService, translationKey: string)
	assert(type(translationKey) == "string", "Bad translationKey")

	if not self._flushScheduled then
		return
	end

	local entry = self._pendingEntries[translationKey]
	if not entry then
		return
	end

	local localizationTable = self:GetLocalizationTable()

	-- The locales a synchronous read may consult: the current locale and the table's source
	-- locale, each plus its bare language subtag, since the Roblox translator falls a
	-- regional locale back to its language (e.g. en-us -> en, and the loaders key the source
	-- under "en"). Landing just these avoids writing every locale in the entry.
	local localeId = self:GetLocaleId()
	local sourceLocaleId = localizationTable.SourceLocaleId
	local readLocales = { localeId, sourceLocaleId }
	local localeSubtag = ResolveLocaleUtils.getLanguageSubtag(localeId)
	if localeSubtag then
		table.insert(readLocales, localeSubtag)
	end
	local sourceSubtag = ResolveLocaleUtils.getLanguageSubtag(sourceLocaleId)
	if sourceSubtag then
		table.insert(readLocales, sourceSubtag)
	end

	-- Land each read locale for this key's pending entry. A landed locale is dequeued, so a
	-- repeated read locale (e.g. localeId already its own subtag) just no-ops the second time.
	for _, readLocale in readLocales do
		self:_landEntryLocale(localizationTable, entry, readLocale)
	end
end

-- Writes one locale's value for a pending entry straight to the table and dequeues just
-- that locale, so the deferred batch flush does not write it again. No-ops if the entry has
-- nothing pending for the locale.
function TranslatorService._landEntryLocale(
	self: TranslatorService,
	localizationTable: LocalizationTable,
	entry: PendingEntry,
	localeId: string
)
	local text = entry.Values[localeId]
	if text == nil then
		return
	end

	local cache = self:_getEntryCache(localizationTable)
	local existing = cache.ByKey[entry.Key]

	-- The text a read needs is already there (another translator registered the same value).
	-- Dequeued so the flush does not write it either.
	--
	-- Deliberately not conditioned on the source/context matching too: a SetEntryValue that
	-- does not change the value does not land new metadata either (engine-behavior.md), so
	-- writing here would move the mirror and not the table. A metadata change stays queued for
	-- the flush, which rebuilds for it.
	if existing and existing.Values[localeId] == text then
		entry.Values[localeId] = nil
		return
	end

	local cached: LocalizationEntry
	if existing then
		cached = existing
	else
		cached = {
			Key = entry.Key,
			Source = entry.Source,
			Context = entry.Context,
			Example = "",
			Values = {},
		}
		cache.ByKey[entry.Key] = cached
		table.insert(cache.List, cached)
	end

	cached.Source = entry.Source
	cached.Context = entry.Context
	cached.Values[localeId] = text

	localizationTable:SetEntryValue(entry.Key, entry.Source, entry.Context, localeId, text)
	entry.Values[localeId] = nil
	self._localizationWriteCount += 1
end

--[=[
	Returns the total number of raw mutating calls made to the localization table. Each
	such call invalidates every AutoLocalize entry in the engine, so this is the cost we
	want to keep low. Primarily useful for diagnostics and regression tests.

	@return number
]=]
function TranslatorService.GetLocalizationWriteCount(self: TranslatorService): number
	return self._localizationWriteCount
end

--[=[
	Returns how many of those writes were full-table `SetEntries` rebuilds, which additionally
	re-serialize every entry in the table. A flush picks between rebuilding and landing
	targeted writes, so this is how a test tells which path a batch took.

	@return number
]=]
function TranslatorService.GetLocalizationRebuildCount(self: TranslatorService): number
	return self._localizationRebuildCount
end

function TranslatorService._scheduleFlush(self: TranslatorService)
	-- A write after teardown must not re-arm the flush: the deferred callback would outlive
	-- the service and write the whole stale queue back into the shared table a frame later.
	if self._flushScheduled or self._isDestroyed then
		return
	end

	self._flushScheduled = true
	self._pendingFlushPromise = Promise.new()

	-- Grouped to the end of the frame. Destroy sets `_flushScheduled = false`, so a
	-- pending flush no-ops (below) if the service is torn down before this runs, rather
	-- than recreating the table.
	task.defer(function()
		self:_flushWrites()
	end)
end

function TranslatorService._flushWrites(self: TranslatorService)
	if not self._flushScheduled then
		return
	end

	self._flushScheduled = false

	local pendingEntries = self._pendingEntries
	self._pendingEntries = {}

	-- Taken before anything can run consumer code. Firing readiness below re-enters this
	-- service -- a handler that registers a key schedules the next flush, which installs its
	-- own promise -- so reading this field afterwards would resolve that batch's promise
	-- instead of this one, and strand everyone awaiting this one.
	local promise = self._pendingFlushPromise
	self._pendingFlushPromise = nil

	if next(pendingEntries) then
		self:_applyPendingEntries(pendingEntries)
	end

	-- After the table is written, so an observer that re-reads on this emission sees the
	-- landed values. Fires for every key in the batch, including ones _applyPendingEntries
	-- skipped as already-matching -- their data is in the table either way, and a key that
	-- never went ready would strand its readers. A key a handler has already re-queued during
	-- this very loop is skipped: it is pending again, and claiming otherwise would publish a
	-- ready state that IsTranslationReady contradicts.
	for translationKey in pendingEntries do
		if self._pendingEntries[translationKey] == nil then
			self:_fireTranslationReady(translationKey)
		end
	end

	if promise then
		promise:Resolve()
	end
end

-- Merges the pending entry deltas into the table's entries and writes back whatever actually
-- changed, by whichever route is cheaper for the size of the batch: a handful of targeted
-- SetEntryValue/SetEntryExample calls, or one SetEntries that rebuilds the table.
function TranslatorService._applyPendingEntries(self: TranslatorService, pendingEntries: PendingEntries)
	local localizationTable = self:GetLocalizationTable()
	local cache = self:_getEntryCache(localizationTable)

	local writes = self:_mergePendingEntries(cache, pendingEntries)

	-- Every queued write already matched the table, so there is nothing to land. Writing
	-- anyway would invalidate the engine's cached contents for no reason.
	if writes and #writes == 0 then
		return
	end

	if writes and self:_shouldWriteIndividually(#writes, #cache.List) then
		for _, write in writes do
			local entry = write.Entry
			local localeId = write.LocaleId
			if localeId ~= nil then
				localizationTable:SetEntryValue(
					entry.Key,
					entry.Source,
					entry.Context,
					localeId,
					entry.Values[localeId]
				)
			else
				localizationTable:SetEntryExample(entry.Key, entry.Source, entry.Context, entry.Example)
			end
			self._localizationWriteCount += 1
		end
		return
	end

	-- A rebuild writes the whole entry list back, so it is the one path that can drop an entry
	-- the mirror never saw. Read the table back first and re-apply this batch on top: this is
	-- the O(table) read the mirror exists to keep out of the hot path, and next to the rebuild
	-- it is about to pay for it is close to free. It also re-syncs the mirror with anything
	-- written behind our back, so a foreign write cannot leave the currency check dropping
	-- writes against a stale mirror indefinitely.
	self:_reconcileEntryCache(localizationTable, cache, pendingEntries)

	localizationTable:SetEntries(cache.List :: any)
	self._localizationWriteCount += 1
	self._localizationRebuildCount += 1
end

-- Rebuilds the mirror from what the table actually holds, with this batch's merged entries
-- kept on top. Anything a foreign writer added or changed is adopted; the keys in this batch
-- win, since the table has not been told about their new values yet.
function TranslatorService._reconcileEntryCache(
	_self: TranslatorService,
	localizationTable: LocalizationTable,
	cache: EntryCache,
	pendingEntries: PendingEntries
)
	local list: { LocalizationEntry } = localizationTable:GetEntries() :: any
	local byKey: { [string]: LocalizationEntry } = {}

	for index, entry in list do
		local merged = if pendingEntries[entry.Key] then cache.ByKey[entry.Key] else nil
		if merged then
			list[index] = merged
			byKey[entry.Key] = merged
		else
			byKey[entry.Key] = entry
		end
	end

	-- Keys this batch is creating are not in the table yet, so the read back cannot have them.
	for translationKey in pendingEntries do
		if byKey[translationKey] == nil then
			local merged = cache.ByKey[translationKey]
			if merged then
				byKey[translationKey] = merged
				table.insert(list, merged)
			end
		end
	end

	cache.List = list
	cache.ByKey = byKey
end

-- Whether to land this many targeted writes rather than rebuild the whole table. One
-- SetEntries costs one invalidation plus re-serializing every entry; N targeted writes cost N
-- invalidations and re-serialize nothing. See INVALIDATION_ENTRY_COST.
function TranslatorService._shouldWriteIndividually(
	_self: TranslatorService,
	writeCount: number,
	entryCount: number
): boolean
	return (writeCount - 1) * INVALIDATION_ENTRY_COST < entryCount
end

-- Merges the deltas into the mirror and returns the targeted writes that would bring the
-- table in line with it, or nil when the batch cannot be expressed as targeted writes at all
-- and has to go through SetEntries.
function TranslatorService._mergePendingEntries(
	_self: TranslatorService,
	cache: EntryCache,
	pendingEntries: PendingEntries
): { PendingWrite }?
	local writes: { PendingWrite } = {}
	local bulkRequired = false

	-- A LocalizationTable keys its entries by translation key alone: SetEntries rejects two
	-- entries sharing a key even when their source/context differ, so we index existing
	-- entries by key and merge each delta into the one entry for its key.
	for _, delta in pendingEntries do
		local existing = cache.ByKey[delta.Key]
		local entry: LocalizationEntry
		if existing then
			entry = existing
		else
			entry = {
				Key = delta.Key,
				Source = delta.Source,
				Context = delta.Context,
				Example = "",
				Values = {},
			}
			cache.ByKey[delta.Key] = entry
			table.insert(cache.List, entry)

			-- A targeted write lands on an entry that exists, and only SetEntryValue is known
			-- to create one, so a new entry carrying nothing but an example cannot be
			-- expressed that way.
			if next(delta.Values) == nil then
				bulkRequired = true
			end
		end

		-- Keep the source/context in step with the latest write for this key, mirroring how
		-- SetEntryValue overwrites them in place.
		local metadataChanged = entry.Source ~= delta.Source or entry.Context ~= delta.Context
		entry.Source = delta.Source
		entry.Context = delta.Context

		local valueWritten = false
		for localeId, text in delta.Values do
			if entry.Values[localeId] ~= text then
				entry.Values[localeId] = text
				table.insert(writes, { Entry = entry, LocaleId = localeId })
				valueWritten = true
			end
		end

		-- Source and context ride along on the value write that changes the entry, and there is
		-- no targeted call that lands them on their own: SetEntryValue updates them only when
		-- it actually changes a value, and rewriting a locale with the text it already holds is
		-- a no-op the metadata does not survive (engine-behavior.md). So a batch that changes
		-- nothing but metadata is rebuilt rather than written -- rare next to the value writes
		-- this path exists for, and the alternative is a metadata change that silently does not
		-- land.
		if metadataChanged and not valueWritten then
			bulkRequired = true
		end

		if delta.Example ~= nil and entry.Example ~= delta.Example then
			entry.Example = delta.Example
			table.insert(writes, { Entry = entry, LocaleId = nil })
		end
	end

	if bulkRequired then
		return nil
	end

	return writes
end

--[=[
	Observes Roblox translator

	@return Observable<Translator>
]=]
function TranslatorService.ObserveTranslator(self: TranslatorService): Observable.Observable<Translator>
	return self._translator:Observe()
end

--[=[
	Promises the Roblox translator

	@return Observable<Translator>
]=]
function TranslatorService.PromiseTranslator(self: TranslatorService): Promise.Promise<Translator>
	local found = self._translator.Value
	if found then
		return Promise.resolved(found)
	end

	if self._pendingTranslatorPromise then
		return self._pendingTranslatorPromise
	end

	local maid = Maid.new()
	local promise = maid:Add(Promise.new())

	self._maid._pendingTranslatorMaid = maid
	self._pendingTranslatorPromise = promise

	maid:GiveTask(function()
		if self._maid._pendingTranslatorMaid == maid then
			self._maid._pendingTranslatorMaid = nil
		end

		if self._pendingTranslatorPromise == promise then
			self._pendingTranslatorPromise = nil
		end
	end)

	maid:GiveTask(self._translator:Observe():Subscribe(function(translator: Translator)
		if translator then
			promise:Resolve(translator)
		end
	end))

	return promise
end

--[=[
	Gets the current translator to use

	@return Translator?
]=]
function TranslatorService.GetTranslator(self: TranslatorService): Translator?
	return self._translator.Value
end

--[=[
	Observes the current locale id for this translator.

	@return Observable<string>
]=]
function TranslatorService.ObserveLocaleId(self: TranslatorService): Observable.Observable<string>
	if self._localeIdValue then
		return self._localeIdValue:Observe()
	end

	local valueObject = self._maid:Add(ValueObject.new("en-us", "string"))

	valueObject:Mount(self._forcedLocaleId:Observe():Pipe({
		Rx.switchMap(function(forcedLocaleId: string?): any
			if forcedLocaleId ~= nil then
				return Rx.of(forcedLocaleId)
			end

			return self:_observeInferredLocaleId()
		end) :: any,
		Rx.distinct() :: any,
	}) :: any)
	self._localeIdValue = valueObject
	return valueObject:Observe()
end

function TranslatorService._observeInferredLocaleId(self: TranslatorService): Observable.Observable<string>
	return self._translator:Observe():Pipe({
		Rx.switchMap(function(translator: Translator): any
			if translator then
				return RxInstanceUtils.observeProperty(translator, "LocaleId")
			else
				-- Fallback
				return self:_observeLoadedPlayer():Pipe({
					Rx.switchMap(function(player: Player)
						if player then
							return RxInstanceUtils.observeProperty(player, "LocaleId")
						else
							return RxInstanceUtils.observeProperty(LocalizationService, "RobloxLocaleId")
						end
					end) :: any,
				})
			end
		end) :: any,
	}) :: any
end

--[=[
	Gets the localeId to use

	@return string
]=]
function TranslatorService.GetLocaleId(self: TranslatorService): string
	local forced = self._forcedLocaleId.Value
	if forced ~= nil then
		return forced
	end

	local found = self._translator.Value
	if found then
		return found.LocaleId
	end

	-- Fallback
	local player = Players.LocalPlayer
	if player and player.LocaleId ~= "" then
		return player.LocaleId
	else
		return LocalizationService.RobloxLocaleId
	end
end

function TranslatorService._observeTranslatorImpl(self: TranslatorService): Observable.Observable<Translator>
	return self:_observeLoadedPlayer():Pipe({
		Rx.switchMap(function(loadedPlayer: Player): any
			if loadedPlayer then
				return Rx.fromPromise(LocalizationServiceUtils.promisePlayerTranslator(loadedPlayer))
			end

			return RxInstanceUtils.observeProperty(LocalizationService, "RobloxLocaleId"):Pipe({
				Rx.switchMap(function(localeId: string): any
					-- This can actually take a while (20-30 seconds)
					return Rx.fromPromise(LocalizationServiceUtils.promiseTranslatorForLocale(localeId))
				end) :: any,
			})
		end) :: any,
	}) :: any
end

function TranslatorService._observeLoadedPlayer(self: TranslatorService): Observable.Observable<Player>
	if self._loadedPlayerObservable then
		return self._loadedPlayerObservable
	end

	local observable: any = RxInstanceUtils.observeProperty(Players, "LocalPlayer"):Pipe({
		Rx.switchMap(function(player: Player): any
			if not player then
				return Rx.of(nil)
			end

			return RxInstanceUtils.observeProperty(player, "LocaleId"):Pipe({
				Rx.map(function(localeId): Player?
					if localeId == "" then
						return nil
					else
						return player
					end
				end) :: any,
			})
		end) :: any,
		Rx.distinct() :: any,
		Rx.cache() :: any,
	})
	self._loadedPlayerObservable = observable

	return observable
end

function TranslatorService.Destroy(self: TranslatorService)
	-- Ensures a still-pending deferred flush no-ops instead of recreating the table, and that
	-- a later write cannot arm a new one.
	self._isDestroyed = true
	self._flushScheduled = false

	-- Everything waiting on a batch that will now never be written is released rather than
	-- left hanging for the lifetime of the place: readiness observers of still-pending keys
	-- first, then the flush promise. Ready is the honest answer -- nothing is queued anymore.
	local pendingEntries = self._pendingEntries
	self._pendingEntries = {}
	for translationKey in pendingEntries do
		self:_fireTranslationReady(translationKey)
	end
	table.clear(self._readyObservers)

	local promise = self._pendingFlushPromise
	self._pendingFlushPromise = nil
	if promise then
		promise:Resolve()
	end

	self._maid:DoCleaning()
end

return TranslatorService
